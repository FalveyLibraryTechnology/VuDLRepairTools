<?php

require_once __DIR__ . '/config.php';

$outDir = 'process-md/';

$pids = [];

foreach (file('storedProcess.txt') as $line) {
  preg_match('/vudl:\d+/', $line, $matches);
  $filename = 'info:fedora/' . $matches[0] . '/PROCESS-MD/PROCESS-MD.0';
  $full = DATASTREAM_STORE_PATH . substr(md5($filename), 0, 2) . '/' . urlencode($filename);
  preg_match('/vudl%3A(\d+)/', $full, $matches);
  copy(trim($full), $outDir . 'vudl_' . $matches[1] . '.xml');
  $pids[] = 'vudl:' . $matches[1];
}

file_put_contents($outDir . 'pidlist.txt', implode("\n", $pids));