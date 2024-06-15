from neo4j import GraphDatabase

class Database:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))

    def close(self):
        self.driver.close()

    def execute_query(self, query, parameters=None, raw=False):
        with self.driver.session() as session:
            result = session.write_transaction(self._execute_query, query, parameters, raw)
            return result
        
    def get_all(self):
        query = """
        MATCH (n) RETURN n
        """
        return self.execute_query(query)
    
    def delete_all(self):
        query = """
        MATCH (n) DETACH DELETE n
        """
        return self.execute_query(query)
    
    def get_attack_paths(self, pq, threat, min_risk_score, limit):
        with self.driver.session() as session:
          with session.begin_transaction() as tx:
            attack_paths = tx.run(pq, threat=threat, min_risk_score=min_risk_score, limit=limit)
            return self.parse_meta_paths(attack_paths)
    
    def get_paths(self, pq, aqs, mqs, threat, min_risk_score, limit, updated_at):
        with self.driver.session() as session:
          with session.begin_transaction() as tx:
            start_meta_paths = tx.run(pq, threat=threat, min_risk_score=min_risk_score, limit=limit)
            for aq in aqs:
                tx.run(aq)
            for mq in mqs:
                tx.run(mq, updated_at=updated_at) 
            new_meta_paths = tx.run(pq, threat=threat, min_risk_score=min_risk_score, limit=limit)

            print("Paths Before")
            og_paths = self.parse_meta_paths(start_meta_paths)
            print("Paths After") 
            tx_paths = self.parse_meta_paths(new_meta_paths)
            tx.rollback()

            og_hashes = []
            tx_hashes = []
            for path in og_paths:
                og_hashes.append(path['hash'])
            for path in tx_paths:
                tx_hashes.append(path['hash'])

            pp = []
            present_paths = set(og_hashes) & set(tx_hashes)
            if len(present_paths) > 0:
                print("Present Paths")
                for path in og_paths:
                  if path['hash'] in present_paths:
                    pp.append(path)
            removed_paths = set(og_hashes) - set(tx_hashes)
            rp = []
            if len(removed_paths) > 0:
              print("Removed Paths")
              for path in og_paths:
                if path['hash'] in removed_paths:
                  rp.append(path)
            new_paths = set(tx_hashes) - set(og_hashes)
            np = []
            if len(new_paths) > 0:
              print("New Paths")
              for path in tx_paths:
                if path['hash'] in new_paths:
                  np.append(path)

            return {
                "added": np,
                "present": pp,
               "removed": rp,
            }
          
    def get_meta_label(self, labels):
        for label in list(labels):
          if label in ["USER", "WORKLOAD", "CREDENTIAL", "STORAGE", "CONTROL_PLANE"]:
            return label
        return "UNKNOWN"
       
    def parse_meta_paths(self, meta_paths):
        paths = []
        for meta_path in meta_paths:
            return_path = {}
            path = meta_path.get('path')
            path_string = ""
            path_hash = ""
            for rel in path.relationships:
                start_node = rel.nodes[0]
                start_node_id = start_node.element_id
                start_node_display = start_node._properties.get('display')
                end_node = rel.nodes[1]
                end_node_id = end_node.element_id
                end_node_display = end_node._properties.get('display')
                rel_name = rel.type
                rel_id = rel.element_id
                rel_cost = round(rel._properties.get('cost'))
                rel_score = round(rel._properties.get('score'))
                rel_title = rel._properties.get('title')
                rel_tech = rel._properties.get('tech')
                sn_label=self.get_meta_label(start_node.labels)
                en_label=self.get_meta_label(end_node.labels)

                rel_details = f"cost: {rel_cost}, score: {rel_score}, title: '{rel_title}', tech: '{rel_tech}']"
                # check if first element
                if rel == path.relationships[0]:
                    # print without new line
                    path_string += f"({sn_label}:{start_node_display}) -[ {rel_name}:{rel_details} ] -> "
                    path_hash += f"n{start_node_id}-r{rel_id}->"
                # check if last element
                elif rel == path.relationships[-1]:
                    path_string += f" -[ {rel_name}:{rel_details} ] -> ({en_label}:{end_node_display})"
                    path_hash += f"n{start_node_id}-r{rel_id}->n{end_node_id}"
                else:
                    # print without new line
                    path_string += f"({sn_label}:{start_node_display}) -[ {rel_name}:{rel_details} ] -> ({en_label}:{end_node_display})"
                    path_hash += f"n{start_node_id}-r{rel_id}->"
            
            risk = meta_path.get('risk')
            risk_string = f"Risk: {round(risk, 2)}"
            print(path_hash) 
            print(risk_string + " Path: " + path_string)
            return_path['hash'] = path_hash
            return_path['path'] = path_string
            return_path['risk'] = risk
            paths.append(return_path)
        
        return paths

    @staticmethod
    def _execute_query(tx, query, parameters, raw=False):
        result = tx.run(query, parameters)
        try:
            if raw:
                response = {
                    "columns": result.keys(),
                    "data": [result.values()]
                }
                return response
            return [record for record in result]
        except Exception as e:
            return {"error": str(e)}