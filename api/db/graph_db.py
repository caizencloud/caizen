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

    @staticmethod
    def _execute_query(tx, query, parameters, raw=False):
        result = tx.run(query, parameters)
        try:
            if raw:
                return result.data()
            return [record for record in result]
        except Exception as e:
            return {"error": str(e)}