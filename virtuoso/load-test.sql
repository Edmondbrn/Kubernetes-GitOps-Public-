ld_dir('/data/model', '*.ttl', 'model-graph');
ld_dir('/data/data', '*.ttl', 'data-graph');
rdf_loader_run();

rdfs_rule_set('sub_class_rules', 'model-graph');
rdfs_rule_set('sub_class_rules', 'data-graph');