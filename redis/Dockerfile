FROM redis:4.0
RUN apt-get update && apt-get install -y git build-essential
RUN mkdir /rebloom
RUN cd /rebloom && git clone https://github.com/RedisBloom/RedisBloom.git #redo
RUN cd /rebloom/RedisBloom && make

COPY redis.conf /data/redis.conf

CMD redis-server /data/redis.conf --loadmodule /rebloom/RedisBloom/redisbloom.so 