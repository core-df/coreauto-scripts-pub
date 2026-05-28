<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
final class Transformclient
{
    public static function JsonParse(string $text): array
    {
        try {
            return ['status_code' => 200, 'data' => json_decode($text, true, 512, JSON_THROW_ON_ERROR)];
        } catch (JsonException $e) {
            return ['status_code' => 400, 'error' => $e->getMessage()];
        }
    }

    public static function JsonStringify(mixed $data, ?int $indent = null): array
    {
        try {
            $flags = JSON_THROW_ON_ERROR | ($indent !== null ? JSON_PRETTY_PRINT : 0);
            return ['status_code' => 200, 'text' => json_encode($data, $flags)];
        } catch (JsonException $e) {
            return ['status_code' => 400, 'error' => $e->getMessage()];
        }
    }

    public static function CsvToRows(string $text, string $delimiter = ','): array
    {
        $lines = preg_split("/\r\n|\n|\r/", trim($text));
        if (!$lines) {
            return ['status_code' => 400, 'error' => 'empty csv'];
        }
        $headers = str_getcsv(array_shift($lines), $delimiter);
        $rows = [];
        foreach ($lines as $line) {
            if ($line === '') continue;
            $vals = str_getcsv($line, $delimiter);
            $row = [];
            foreach ($headers as $i => $h) {
                $row[$h] = $vals[$i] ?? '';
            }
            $rows[] = $row;
        }
        return ['status_code' => 200, 'rows' => $rows];
    }

    public static function RowsToCsv(array $rows, string $delimiter = ','): array
    {
        if (!$rows) {
            return ['status_code' => 400, 'error' => 'rows must not be empty'];
        }
        $headers = array_keys($rows[0]);
        $out = implode($delimiter, $headers) . "\n";
        foreach ($rows as $row) {
            $out .= implode($delimiter, array_map(fn($h) => $row[$h] ?? '', $headers)) . "\n";
        }
        return ['status_code' => 200, 'text' => $out];
    }

    public static function XmlToDict(string $text): array
    {
        libxml_use_internal_errors(true);
        $xml = simplexml_load_string($text);
        if ($xml === false) {
            return ['status_code' => 400, 'error' => 'xml parse error'];
        }
        $data = [$xml->getName() => self::xmlElem($xml)];
        return ['status_code' => 200, 'data' => $data];
    }

    private static function xmlElem(SimpleXMLElement $node): mixed
    {
        $children = $node->children();
        if (count($children) === 0) {
            return trim((string) $node);
        }
        $out = [];
        foreach ($children as $child) {
            $tag = $child->getName();
            $val = self::xmlElem($child);
            if (isset($out[$tag])) {
                if (!is_array($out[$tag]) || !isset($out[$tag][0])) {
                    $out[$tag] = [$out[$tag]];
                }
                $out[$tag][] = $val;
            } else {
                $out[$tag] = $val;
            }
        }
        return $out;
    }

    public static function DictToXml(array $data, string $root_tag = 'root'): array
    {
        $root = new SimpleXMLElement('<' . $root_tag . '/>');
        foreach ($data as $k => $v) {
            self::buildXml($root, $v, (string) $k);
        }
        return ['status_code' => 200, 'text' => $root->asXML()];
    }

    private static function buildXml(SimpleXMLElement $parent, mixed $obj, string $tag): void
    {
        if (is_array($obj) && array_is_list($obj)) {
            foreach ($obj as $item) {
                self::buildXml($parent, $item, $tag);
            }
            return;
        }
        if (is_array($obj)) {
            $node = $parent->addChild($tag);
            foreach ($obj as $k => $v) {
                self::buildXml($node, $v, (string) $k);
            }
            return;
        }
        $node = $parent->addChild($tag);
        $node[0] = $obj === null ? '' : (string) $obj;
    }
}
