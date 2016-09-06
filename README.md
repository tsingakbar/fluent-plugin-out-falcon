# fluent-plugin-out-falcon, a plugin for [Fluentd](http://fluentd.org)

A [fluentd][1] output plugin for sending logs to [falcon][2]'s push api.

## Configuration options

    <match *>
      type http
      endpoint_url    http://localhost.local/api/
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
