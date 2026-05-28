<?php
declare(strict_types=1);
/*
 * Copyright Core DF — Apache License 2.0
 */
require_once __DIR__ . '/../../../http/PHP/lib/result.php';

final class Fileclient
{
    public static function LocalRead(string $path, string $encoding = 'utf-8'): array
    {
        try {
            return ['status_code' => 200, 'content' => file_get_contents($path)];
        } catch (Throwable $e) {
            return ['status_code' => 500, 'error' => $e->getMessage()];
        }
    }

    public static function LocalWrite(string $path, string $content, string $encoding = 'utf-8'): array
    {
        $dir = dirname($path);
        if ($dir !== '.' && !is_dir($dir)) {
            mkdir($dir, 0775, true);
        }
        if (file_put_contents($path, $content) === false) {
            return ['status_code' => 500, 'error' => 'write failed'];
        }
        return ['status_code' => 200];
    }

    public static function LocalMove(string $src, string $dest): array
    {
        if (!rename($src, $dest)) {
            return ['status_code' => 500, 'error' => 'move failed'];
        }
        return ['status_code' => 200];
    }

    private static function sftpConnect()
    {
        if (!class_exists('phpseclib3\\Net\\SFTP')) {
            throw new RuntimeException('phpseclib/phpseclib required');
        }
        $host = getenv('SFTP_HOST') ?: '';
        $user = getenv('SFTP_USER') ?: '';
        $password = getenv('SFTP_PASSWORD') ?: '';
        $port = (int)(getenv('SFTP_PORT') ?: '22');
        $keyPath = getenv('SFTP_PRIVATE_KEY') ?: '';
        if ($host === '' || $user === '') {
            throw new RuntimeException('SFTP_HOST and SFTP_USER required');
        }
        $sftp = new phpseclib3\Net\SFTP($host, $port);
        if ($keyPath !== '') {
            $key = phpseclib3\Crypt\PublicKeyLoader::load(file_get_contents($keyPath));
            if (!$sftp->login($user, $key)) {
                throw new RuntimeException('sftp key login failed');
            }
        } else {
            if ($password === '') {
                throw new RuntimeException('SFTP_PASSWORD or SFTP_PRIVATE_KEY required');
            }
            if (!$sftp->login($user, $password)) {
                throw new RuntimeException('sftp login failed');
            }
        }
        return $sftp;
    }

    public static function SftpGet(string $remote_path, string $local_path): array
    {
        try {
            $sftp = self::sftpConnect();
            $dir = dirname($local_path);
            if ($dir !== '.' && !is_dir($dir)) {
                mkdir($dir, 0775, true);
            }
            if (!$sftp->get($remote_path, $local_path)) {
                return ['status_code' => 500, 'error' => 'sftp get failed'];
            }
            return ['status_code' => 200];
        } catch (Throwable $e) {
            return ['status_code' => 500, 'error' => $e->getMessage()];
        }
    }

    public static function SftpPut(string $local_path, string $remote_path): array
    {
        try {
            $sftp = self::sftpConnect();
            if (!$sftp->put($remote_path, $local_path, phpseclib3\Net\SFTP::SOURCE_LOCAL_FILE)) {
                return ['status_code' => 500, 'error' => 'sftp put failed'];
            }
            return ['status_code' => 200];
        } catch (Throwable $e) {
            return ['status_code' => 500, 'error' => $e->getMessage()];
        }
    }
}
