# fluent-plugin-out-falcon, a plugin for [Fluentd](http://fluentd.org)

A [fluentd][1] output plugin for sending logs to [falcon][2]'s push API.

## Configuration options

`record` option will be posted to falcon.
It can only be in one line(limited by fluentd), in the form as `([{ruby_hash_items},{ruby_hash_items},...])`.
The outsider `()` is used to avoid fluentd interpret this line as json.
You can use `tag`, `time` and `record` variables while writing ruby\_hash.

    <source>
      @type dummy
      tag xx.yyy
      dummy {"ip":"8.8.8.8", "data1":888, "data2": "message"} 
    </source>
    <match xx.yyy>
      type falcon
      endpoint_url    http://localhost:1988/v1/push
      records         ([{'metric'=>'number_data', 'endpoint'=>record['ip'], 'timestamp'=>time, 'value'=>record['data1'], 'step'=>1, 'counterType'=>'GAUGE', 'tags'=>nil}, {'metric'=>'string_data', 'endpoint'=>record['ip'], 'timestamp'=>time, 'value'=>record['data2'], 'step'=>1, 'counterType'=>'GAUGE', 'tags'=>nil}])
      rate_limit_msec 100    # default: 0 = no rate limiting
      raise_on_error  false  # default: true
      authentication  basic  # default: none
      username        alice  # default: ''
      password        bobpop # default: '', secret: true
    </match>


----

Heavily based on [fluent-plugin-out-http][3]

  [1]: http://fluentd.org/
  [2]: http://open-falcon.org/
  [3]: https://github.com/https://github.com/ento/fluent-plugin-out-http
