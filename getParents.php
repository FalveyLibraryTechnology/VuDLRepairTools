<?php

require_once __DIR__ . '/config.php';

$pids = array_map('trim', file('bad-pids.txt'));

$out = fopen('parents.csv', 'w');

foreach ($pids as $pid) {
  echo "Checking $pid...\n";
  $parents = getParents($pid);
  fputcsv($out, array_merge([$pid], $parents));
}

fclose($out);

function getParents($pid)
{
    $url = SOLR_QUERY_URL . '?fl=hierarchy_all_parents_str_mv&q=hierarchy_parent_id%3A%22' . urlencode($pid) . '%22+modeltype_str_mv%3A%22vudl-system%3AListCollection%22&wt=csv';
    $response = file_get_contents($url);
    $parts = explode("\n", trim($response));
    $allParents = explode(',', trim($parts[1], '"'));
    if (empty($allParents)) {
      throw new \Exception('missing parents!');
    }
    $allParents = array_diff(array_unique($allParents), [$pid]);
    $knownParents = [];
    foreach ($allParents as $parent) {
      $knownParents = array_merge($knownParents, getImmediateParents($parent));
    }
    $finalParents = array_diff($allParents, $knownParents);
    return $finalParents;
}

function getImmediateParents($pid)
{
    static $parentCache = [];
    if (!isset($parentCache[$pid])) {
      $url = SOLR_QUERY_URL . '?q=id%3A%22' . urlencode($pid) . '%22&fl=hierarchy_parent_id&wt=csv&indent=true';
      $response = file_get_contents($url);
      $parts = explode("\n", trim($response));
      $parentCache[$pid] = explode(',', trim($parts[1], '"'));
    }
    return $parentCache[$pid];
}
