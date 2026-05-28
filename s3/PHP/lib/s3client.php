<?php
declare(strict_types=1);
/*
 * Copyright Core DF
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * S3-compatible object storage helpers (AWS S3, MinIO, etc.).
 */
require_once __DIR__ . '/../../../http/PHP/lib/result.php';

$autoload = __DIR__ . '/../vendor/autoload.php';
if (is_file($autoload)) {
    require_once $autoload;
}

use Aws\S3\S3Client as AwsS3Client;

final class S3client
{
    private static function region(): string
    {
        $r = getenv('AWS_REGION') ?: getenv('AWS_DEFAULT_REGION') ?: '';
        return $r !== '' && $r !== false ? $r : 'us-east-1';
    }

    private static function aws(): AwsS3Client
    {
        $config = ['version' => 'latest', 'region' => self::region()];
        $endpoint = getenv('S3_ENDPOINT_URL') ?: '';
        if ($endpoint !== '') {
            $config['endpoint'] = $endpoint;
            $config['use_path_style_endpoint'] = true;
        }
        return new AwsS3Client($config);
    }

    private static function bucket(?string $explicit): string
    {
        if ($explicit !== null && $explicit !== '') {
            return $explicit;
        }
        $b = getenv('S3_BUCKET');
        return $b !== false ? $b : '';
    }

    public static function Init(): array
    {
        $key = getenv('AWS_ACCESS_KEY_ID') ?: '';
        $profile = getenv('AWS_PROFILE') ?: '';
        if ($key === '' && $profile === '') {
            return CoreautoResult::missingEnv('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE');
        }
        if (self::bucket(null) === '') {
            return CoreautoResult::missingEnv('S3_BUCKET (or pass bucket per call)');
        }
        return ['status_code' => 200];
    }

    public static function GetObject(string $key, ?string $bucketName = null): array
    {
        $b = self::bucket($bucketName);
        if ($b === '') {
            return CoreautoResult::missingEnv('S3_BUCKET');
        }
        if (!class_exists(AwsS3Client::class)) {
            return CoreautoResult::transportError('Run composer install in s3/PHP (aws/aws-sdk-php)');
        }
        try {
            $result = self::aws()->getObject(['Bucket' => $b, 'Key' => $key]);
            $content = (string) ($result['Body'] ?? '');
            return ['status_code' => 200, 'content' => $content];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }

    public static function PutObject(string $key, string $content, ?string $bucketName = null): array
    {
        $b = self::bucket($bucketName);
        if ($b === '') {
            return CoreautoResult::missingEnv('S3_BUCKET');
        }
        if (!class_exists(AwsS3Client::class)) {
            return CoreautoResult::transportError('Run composer install in s3/PHP (aws/aws-sdk-php)');
        }
        try {
            self::aws()->putObject([
                'Bucket' => $b,
                'Key' => $key,
                'Body' => $content,
            ]);
            return ['status_code' => 200];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }

    public static function ListObjects(string $prefix = '', ?string $bucketName = null): array
    {
        $b = self::bucket($bucketName);
        if ($b === '') {
            return CoreautoResult::missingEnv('S3_BUCKET');
        }
        if (!class_exists(AwsS3Client::class)) {
            return CoreautoResult::transportError('Run composer install in s3/PHP (aws/aws-sdk-php)');
        }
        try {
            $result = self::aws()->listObjectsV2([
                'Bucket' => $b,
                'Prefix' => $prefix,
            ]);
            $keys = [];
            foreach ($result['Contents'] ?? [] as $obj) {
                if (isset($obj['Key'])) {
                    $keys[] = $obj['Key'];
                }
            }
            return ['status_code' => 200, 'keys' => $keys];
        } catch (Throwable $e) {
            return CoreautoResult::transportError($e->getMessage());
        }
    }
}
