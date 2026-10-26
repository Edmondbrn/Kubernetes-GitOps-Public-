ld_dir('/data/rdf-class', '*.ttl', 'model-graph');
ld_dir('/data/chicken', '*.ttl.gz', 'data-graph');
ld_dir('/data/deepimpact', '*.ttl.gz', 'data-graph');
rdf_loader_run();

rdfs_rule_set('sub_class_rules', 'model-graph');