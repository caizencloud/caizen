-- Every row that packs insert. The loader replaces them all on each load.
DELETE FROM feed_manifest;
DELETE FROM edge_type;
DELETE FROM edge_endpoint;
DELETE FROM class_value;
DELETE FROM node_type;
DELETE FROM value_class;
DELETE FROM storage_prior;
DELETE FROM pack_query;
