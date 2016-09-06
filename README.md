# fluent-plugin-out-falcon, a plugin for [Fluentd](http://fluentd.org)

A [fluentd][1] output plugin for sending logs to [falcon][2]'s push API.
This plugin won't modify the record to be post, so most of the time you might want to
combine using the filter plugin `fluent-plugin-record-modifier`.

## Configuration options

    <filter xx.yyy>
      @type record\_modifier
      <record>
        metric message_sent
        endpoint ${record['Comet']}   # use one record field as the endpoint
        timestamp ${Time.now.to_i}    # quote with ${} to avoid translate the int to string in json
        value ${record['MsgSent']}    # use one record field as the value
        step ${1}                     # quote with ${} to avoid translate the int to string in json
        counterType GAUGE
        tags ''
      </record>
      remove\_keys Comet,CurConn,Auth,MsgRecv,HBRecv,RecvDrop,MsgSent,HBReply,SendDrop,TX
    </filter>

    <match xx.yyy>
      type falcon
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
