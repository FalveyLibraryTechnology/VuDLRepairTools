<?php

require_once __DIR__ . '/config.php';

$in = file('bad-pids.txt');

$out = fopen('bad-pids-with-titles.csv', 'w');

foreach ($in as $pid) {
  $title = getTitle(trim($pid));
  fputcsv($out, [trim($pid), $title]);
}

fclose($out);

function getTitle($pid) {
    echo "Getting title for $pid...\n";
    $result = file_get_contents(SOLR_QUERY_URL . '?q=hierarchy_parent_id%3A%22' . urlencode($pid) . '%22&rows=1&fl=hierarchy_parent_title&wt=csv&indent=true');
    $parts = explode("\n", $result);
    return trim($parts[1]);
}
