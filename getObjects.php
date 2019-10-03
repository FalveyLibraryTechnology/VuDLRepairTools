<?php

require_once __DIR__ . '/config.php';

$pids = file('bad-pids.txt');
$outDir = 'objects/';

foreach ($pids as $rawPid) {
  $pid = trim($rawPid);
  $fedoraFilename = 'info:fedora/' . $pid;
  $md5 = substr(md5($fedoraFilename), 0, 2);
  copy(OBJECT_STORE_PATH . $md5 . '/' . urlencode($fedoraFilename), $outDir . str_replace(':', '_', $pid) . '.xml');
}
