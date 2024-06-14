import json
from neo4j import GraphDatabase, RoutingControl
 
# Define correct URI and AUTH arguments (no AUTH by default)
URI = "bolt://localhost:7687"
AUTH = ("", "")

min_path_score = 10

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
  toFloat(0.900) as threat,
  reduce(tlikelihood = 1, tc IN tcost | tlikelihood * tc) as likelihood,
  reduce(impact = 0, rel in relationships(path) | impact + rel.score) as impact, techs
WITH path, n, e[-1] as last_edge, threat, likelihood, impact, (threat * likelihood * impact) as risk, techs
WHERE risk > 0 and type(last_edge) IN ["IMPACT"] and all(rel in relationships(path)[1..size(relationships(path))-2] WHERE type(rel) IN ["IMPACT"]) IS NULL
RETURN DISTINCT path, last_edge, threat, likelihood, impact, risk, techs
ORDER BY risk desc LIMIT $limit
"""

transaction_query = """
MERGE (p:GCP_CLOUDRESOURCEMANAGER_PROJECT {id:"cloudresourcemanager.googleapis.com/projects/18879573367"})
MERGE (ir:GCP_IAM_ROLE {id:"roles/editor", display: "Role: Project Editor"})
MERGE (gsa:GCP_IDENTITY {id:"serviceAccount:api-sa@ln-prod-web.iam.gserviceaccount.com", name:"api-sa@ln-prod-web.iam.gserviceaccount.com", type:"serviceAccount", display: "SA: api-sa@ln-prod-web"})
MERGE (gsa)-[:HAS_IAMROLE {name: "roles/editor"}]->(p)
MERGE (gsa)-[:HAS_ACCESSVIA {resource: "cloudresourcemanager.googleapis.com/projects/18879573367", resource_type:"GCP_CLOUDRESOURCEMANAGER_PROJECT"}]->(ir)
MERGE (ir)-[:IS_GRANTEDTO {identity:"serviceAccount:api-sa@ln-prod-web.iam.gserviceaccount.com", identity_name: "api-sa@ln-prod-web.iam.gserviceaccount.com", identity_type: "serviceAccount"}]->(p)
"""

transaction_query2 = """
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

transaction_query3 = """
MATCH (gi:GCP_IDENTITY {id: "serviceAccount:api-sa@ln-prod-web.iam.gserviceaccount.com"})-[hir:HAS_IAMROLE {name: "roles/editor"}]->(p:GCP_CLOUDRESOURCEMANAGER_PROJECT {id:"cloudresourcemanager.googleapis.com/projects/18879573367"})
DELETE hir
"""
transaction_query4 = """
MATCH (c:CREDENTIAL {id: "serviceAccount:api-sa@ln-prod-web.iam.gserviceaccount.com"})-[i:IMPACT]->(t:CONTROL_PLANE)
DELETE i
"""

def get_meta_label(labels):
  for label in list(labels):
    if label in ["USER", "WORKLOAD", "CREDENTIAL", "STORAGE", "CONTROL_PLANE"]:
      return label
  return "UNKNOWN"


def parse_meta_paths(meta_paths):
    paths = []
    for meta_path in meta_paths:
        return_path = {}
        path = meta_path.get('path')
        path_string = ""
        path_hash = ""
        for rel in path.relationships:
            start_node = rel.nodes[0]
            start_node_id = start_node.element_id
            end_node = rel.nodes[1]
            end_node_id = end_node.element_id
            rel_name = rel.type
            rel_id = rel.element_id
            sn_label=get_meta_label(start_node.labels)
            en_label=get_meta_label(end_node.labels)
            # check if first element
            if rel == path.relationships[0]:
                # print without new line
                path_string += f"({sn_label} {{ id: {start_node_id} }}) -[{rel_name} {{ id: {rel_id}}}]->"
                path_hash += f"n{start_node_id}-r{rel_id}->"
            # check if last element
            elif rel == path.relationships[-1]:
                path_string += f" -[{rel_name} {{ id: {rel_id}}}]-> ({en_label} {{ id: {end_node_id} }})"
                path_hash += f"n{start_node_id}-r{rel_id}->n{end_node_id}"
            else:
                # print without new line
                path_string += f"({sn_label} {{ id: {start_node_id} }}) -[{rel_name} {{ id: {rel_id}}}]-> ({en_label} {{ id: {end_node_id} }})"
                path_hash += f"n{start_node_id}-r{rel_id}->"
        
        risk = meta_path.get('risk')
        risk_string = f"Risk: {round(risk, 2)}"
        print(path_hash)
        print(risk_string + " Path: " + path_string)
        return_path['hash'] = path_hash
        return_path['path'] = path_string
        return_path['risk'] = risk
        paths.append(return_path)
    print("")
    return paths
 
with GraphDatabase.driver(URI, auth=AUTH, encrypted=False) as client:
    # Check the connection
    client.verify_connectivity()

    # Start a transaction
    with client.session() as session:
        # Start a transaction
        with session.begin_transaction() as tx:
            # Run the transactional queries to add new paths
            tx.run(transaction_query)
            tx.run(transaction_query2)
            start_meta_paths = tx.run(path_query, score=min_path_score, limit=20)
            tx.run(transaction_query3)
            tx.run(transaction_query4)
            # Get the mocked paths
            new_meta_paths = tx.run(path_query, score=min_path_score, limit=20)

            print("Paths Before")
            og_paths = parse_meta_paths(start_meta_paths)
            print("Paths After")
            tx_paths = parse_meta_paths(new_meta_paths)
            tx.rollback()

            og_hashes = []
            tx_hashes = []
            for path in og_paths:
                og_hashes.append(path['hash'])
            for path in tx_paths:
                tx_hashes.append(path['hash'])

            removed_paths = set(og_hashes) - set(tx_hashes)
            if len(removed_paths) > 0:
              print("Removed Paths")
              for path in og_paths:
                if path['hash'] in removed_paths:
                  print(path)

            new_paths = set(tx_hashes) - set(og_hashes)
            if len(new_paths) > 0:
              print("New Paths")
              for path in tx_paths:
                if path['hash'] in new_paths:
                  print(path)
