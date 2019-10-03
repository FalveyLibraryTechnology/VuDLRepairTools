<?php

require_once __DIR__ . '/config.php';

$pids = array_map('trim', file('bad-pids.txt'));

$good = fopen('thumbs.csv', 'w');
$bad = fopen('thumbs-missing.csv', 'w');

foreach ($pids as $pid) {
  echo "Checking $pid... ";
  $thumb = getThumb($pid);
  if (empty($thumb)) {
    echo "found!\n";
    fputcsv($bad, [$pid]);
  } else {
    echo "not found!\n";
    fputcsv($good, [$pid, $thumb]);
  }
}

fclose($good);
fclose($bad);

function getThumb($pid)
{
    $url = SOLR_QUERY_URL . '?q=hierarchy_all_parents_str_mv%3A%22' . urlencode($pid) . '%22+modeltype_str_mv%3A%22vudl-system%3AImageData%22&sort=id+asc&rows=1000&fl=id%2Chierarchy_sequence&wt=csv&indent=true';
    $response = file_get_contents($url);
    $parts = explode("\n", trim($response));
    $pos = 999999;
    $thumb = null;
    for ($x = 1; $x < count($parts); $x++) {
       list($id, $num) = explode(',', $parts[$x]);
       if (intval($num) < $pos) {
         $pos = intval($num);
         $thumb = $id;
       }
    }
    return $thumb;
}
