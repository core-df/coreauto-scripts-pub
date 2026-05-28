// Copyright Core DF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.coredf.redis;
import redis.clients.jedis.Jedis; import java.util.*;

public final class RedisClient {
    private RedisClient() {}
    private static String url() {
        String u = MsgUtil.env("REDIS_URL"); if (!u.isEmpty()) return u;
        String host = MsgUtil.env("REDIS_HOST"); if (host.isEmpty()) return "";
        String pw = MsgUtil.env("REDIS_PASSWORD"); String db = MsgUtil.envOr("REDIS_DB", "0");
        if (!pw.isEmpty()) return "redis://:" + pw + "@" + host + ":" + MsgUtil.envOr("REDIS_PORT", "6379") + "/" + db;
        return "redis://"+host+":"+MsgUtil.envOr("REDIS_PORT","6379")+"/"+db;
    }
    public static Result Init() { if (url().isEmpty()) return Result.missingEnv("REDIS_URL or REDIS_HOST"); return Result.ok(); }
    public static Result Push(String queue, Object value) {
        if (url().isEmpty()) return Result.missingEnv("REDIS_URL or REDIS_HOST");
        try (Jedis j = new Jedis(url())) { j.lpush(queue.getBytes(), MsgUtil.encode(value)); return Result.ok(); }
        catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Pop(String queue, double timeoutSec, int maxMessages) {
        if (url().isEmpty()) return Result.missingEnv("REDIS_URL or REDIS_HOST");
        List<Map<String, Object>> messages = new ArrayList<>();
        try (Jedis j = new Jedis(url())) {
            int remaining = Math.max(1, maxMessages); double deadline = timeoutSec;
            while (remaining > 0 && deadline > 0) {
                int wait = remaining == maxMessages ? Math.max(1, (int)timeoutSec) : 1;
                List<byte[]> item = j.brpop((int)wait, queue); if (item == null || item.size() < 2) break;
                messages.add(Map.of("queue", queue, "value", MsgUtil.decode(item.get(1)))); remaining--; deadline -= wait;
            }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
        return Result.ok(Map.of("messages", messages));
    }
    public static Result Pop(String queue) { return Pop(queue, 30, 1); }
}
