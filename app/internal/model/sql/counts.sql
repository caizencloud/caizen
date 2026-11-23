SELECT (SELECT count(*) FROM node), (SELECT count(*) FROM abstract_edge),
       (SELECT count(*) FROM edge_reject), (SELECT count(*) FROM goal)
