<?php

// Path to Fedora 3 datastream store from which to extract objects
define('DATASTREAM_STORE_PATH', '/tmp/datastreamStore/');

// Path to Fedora 3 object store from which to extract objects
define ('OBJECT_STORE_PATH', '/tmp/objectStore/');

// URL for performing Solr queries
define('SOLR_QUERY_URL', 'http://localhost:8983/solr/core/select');