<?php
declare(strict_types=1);
$root = dirname(__DIR__, 2);
require_once "$root/cawbs/PHP/cawbs.php";
require_once "$root/files/PHP/lib/Fileclient.php";
require_once "$root/transform/PHP/lib/transformclient.php";
require_once "$root/queues/kafka/PHP/lib/Kafkaclient.php";
require_once "$root/queues/rabbit/PHP/lib/Rabbitclient.php";
require_once "$root/queues/sqs/PHP/lib/Sqsclient.php";
