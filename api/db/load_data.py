import time

path_query = """
MATCH path=(u:USER)-[r:INITIAL_ACCESS|:CREDENTIAL_ACCESS|:PRIVILEGE_ESCALATION|:IMPACT *1..10]->(e)
WHERE u.id = "anonymous" and (e:USER or e:WORKLOAD or e:CREDENTIAL or e:STORAGE or e:CONTROL_PLANE)
WITH
  path,
  nodes(path) as n,
  relationships(path) AS e,
  extract(e in relationships(path)| toFloat(1000 - e.cost)/1000) as tcost,
  extract(e in relationships(path)| e.tech + "." + e.subtech) as techs
WITH
  path,
  n,
  e,
  toFloat($threat) as threat,
  reduce(tlikelihood = 1, tc IN tcost | tlikelihood * tc) as likelihood,
  reduce(impact = 0, rel in relationships(path) | impact + rel.score) as impact, techs
WITH path, n, e, e[-1] as last_edge, threat, likelihood, impact, (threat * likelihood * impact) as risk, techs
WHERE risk >= $min_risk_score and type(last_edge) IN ["IMPACT"] and all(rel in relationships(path)[1..size(relationships(path))-2] WHERE type(rel) IN ["IMPACT"]) IS NULL
RETURN DISTINCT path, e as rels, threat, likelihood, impact, round(risk) as risk, techs
ORDER BY risk desc LIMIT $limit
"""
meta_path_query1 = """
MATCH (gi:GCP_IDENTITY)-[hir:HAS_IAMROLE]->(p:GCP_CLOUDRESOURCEMANAGER_PROJECT)
MATCH (p)<-[ip:IN_PROJECT]-(gi2:GCP_IDENTITY)
MATCH (gi2)-[hir3:HAS_IAMROLE]->(o)
WHERE labels(o)[0] IN ["GCP_CLOUDRESOURCEMANAGER_ORGANIZATION"]
and hir.name = "roles/editor"
and gi != gi2
and hir3.name = "roles/resourcemanager.organizationAdmin"
SET gi:CREDENTIAL, o:CONTROL_PLANE, gi2:CREDENTIAL
WITH gi, gi2, o
MERGE (gi)-[:IMPACT {
  type: "PRIVILEGE_ESCALATION",
  level: "OWNER",
  cost: 100, score: 100000, tech: "T1078", subtech: "004", title: "Valid Accounts: Cloud Accounts",
  escidentity: gi2.name
  }]->(o)
"""

meta_path_query2 = """
MATCH (i:INTERNET)-[]->(w:WORKLOAD {meta: {is_public: true}})-[hr:HAS_REVISION]->(crr:GCP_RUN_REVISION {state: "running"})-[ri:RUNS_IMAGE]->(image)-[hv:HAS_VULNERABILITY]->(v:VULNERABILITY)
WITH w, v, v.details.cvss as cvss
WHERE cvss.attackVector = "NETWORK" and cvss.userInteraction = "NONE"
WITH w, v, cvss, (1000 * log10(11.05 - cvss.baseScore)) as cost
MERGE (u:USER {id: "anonymous", display: "Anonymous User"})
MERGE (u)-[r:INITIAL_ACCESS {cost: cost, score: 700, tech: "T1190", subtech: "000", title: "Exploit Public-Facing Application", meta: v.details}]->(w)
ON CREATE SET r.updated_at = $updated_at
ON MATCH SET r.updated_at = $updated_at
MERGE (w)-[:IMPACT {cost: 10, score: 500, tech: "T1496", subtech: "000", title: "Resource Hijacking"}]->(w)
WITH u, w
MATCH (u)-[r2:INITIAL_ACCESS]->(w)
WHERE r2.updated_at < $updated_at
DELETE r2
"""
meta_queries = []
meta_queries.append(meta_path_query1)
meta_queries.append(meta_path_query2)

class AttackPaths:
    def __init__(self, db, attack_paths):
        self.db = db
        self.threat = attack_paths.threat or 0.9
        self.limit = 20
        self.min_risk_score = 10
        self.updated_at = int(time.time() * 1000)

    def get_paths(self):
        return self.db.get_attack_paths(path_query, self.threat, self.min_risk_score, self.limit)

class ProcessPaths:
    def __init__(self, db, changeset):
        self.db = db
        self.changeset_type = changeset.type
        self.changeset_date = changeset.date
        self.assets = changeset.assets
        self.threat = changeset.threat or 0.9
        self.limit = 20
        self.min_risk_score = 10
        self.updated_at = int(time.time() * 1000)
    
    def get_paths(self):
        asset_queries = self.parse_assets(self.assets)
        return self.db.get_paths(path_query, asset_queries, meta_queries, self.threat, self.min_risk_score, self.limit, self.updated_at)
    
    def parse_assets(self, assets):
        asset_queries = []

        # TODO: make this dynamic
        for asset in assets:
            asset_type = asset.get('type')
            if asset_type == "gcp_run_service":
                asset_query = """
                MERGE (crr:GCP_RUN_REVISION { id: "run.googleapis.com/projects/ln-prod-web/us-central1/service/api/revision/foo-bar" })
                MERGE (ara_old:GCP_ARTIFACTREGISTRY_ARTIFACT {id: "artifactregistry.googleapis.com/projects/ln-prod-automation/us-central1/repository/docker/artifact/api:1.1.1"})
                MERGE (ara_new:GCP_ARTIFACTREGISTRY_ARTIFACT {id: "artifactregistry.googleapis.com/projects/ln-prod-automation/us-central1/repository/docker/artifact/api:1.1.2"})
                MERGE (crr)-[:RUNS_IMAGE]->(ara_new)
                MERGE (crr)-[r:RUNS_IMAGE]->(ara_old)
                DELETE r
                """
                asset_queries.append(asset_query)
            elif asset_type == "gcp_cloudresourcemanager_iam_policy":
                asset_query = """
                MERGE (p:GCP_CLOUDRESOURCEMANAGER_PROJECT {id:"cloudresourcemanager.googleapis.com/projects/18879573367"})
                MERGE (ir:GCP_IAM_ROLE {id:"roles/editor", display: "Role: Project Editor"})
                MERGE (gsa:GCP_IDENTITY {id:"serviceAccount:api-sa@ln-prod-web.iam.gserviceaccount.com", name:"api-sa@ln-prod-web.iam.gserviceaccount.com", type:"serviceAccount", display: "SA: api-sa@ln-prod-web"})
                MERGE (gsa)-[:HAS_IAMROLE {name: "roles/editor"}]->(p)
                MERGE (gsa)-[:HAS_ACCESSVIA {resource: "cloudresourcemanager.googleapis.com/projects/18879573367", resource_type:"GCP_CLOUDRESOURCEMANAGER_PROJECT"}]->(ir)
                MERGE (ir)-[:IS_GRANTEDTO {identity:"serviceAccount:api-sa@ln-prod-web.iam.gserviceaccount.com", identity_name: "api-sa@ln-prod-web.iam.gserviceaccount.com", identity_type: "serviceAccount"}]->(p)
                """
            asset_queries.append(asset_query)

        return asset_queries