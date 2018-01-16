require! <[mkdirp bunyan bunyan-debug-stream bunyan-rotating-file-stream lodash path colors]>
moment = require \moment-timezone

class ModuleLogger
  (@filename) ->
    {logger} = module
    @stream = logger.child base: {filename}

  error: -> return @stream.error.apply @stream, arguments
  warn: -> return @stream.warn.apply @stream, arguments
  info: -> return @stream.info.apply @stream, arguments
  debug: -> return @stream.debug.apply @stream, arguments



GET_LOGGER = (filename) ->
  logger = new ModuleLogger filename
  produce-func = (logger, level) -> return -> logger[level].apply logger, arguments
  return do
    logger: logger.stream
    DBG: produce-func logger, \debug
    ERR: produce-func logger, \error
    WARN: produce-func logger, \warn
    INFO: produce-func logger, \info


DEFAULT_PREFIXERS =
  \base : (base) ->
    {filename} = base
    return "master:0:#{(path.basename filename).gray}"



export init = (opts, done) ->
  {app-context} = global
  {current-dir, log-dir, boot-time} = app-context
  {name, stringifiers} = opts
  prefixers = lodash.defaults {}, DEFAULT_PREFIXERS
  logging-dir = "#{log-dir}/#{boot-time}"
  (mkdir-err) <- mkdirp logging-dir
  return done mkdir-err if mkdir-err?
  logging-opts = name: name, streams: [], serializers: bunyan-debug-stream.serializers
  logging-opts.streams.push do
    level: \info
    type: \raw
    stream: bunyan-debug-stream do
      out: process.stderr
      basepath: current-dir
      forceColor: yes
      showProcess: no
      colors: debug: \gray, info: \white
      prefixers: prefixers
      stringifiers: stringifiers
  logging-opts.streams.push do
    level: \debug
    stream: new bunyan-rotating-file-stream do
      path: "#{logging-dir}/#{name}.%y-%m-%d.log"
      period: \daily
      rotateExisting: no
      threshold: \1g        # The maximum size for a log file to reach before it's rotated.
      totalFiles: 180       # Keep 180 days (6 months) of log files.
      totalSize: 0
      startNewFile: no
      gzip: yes

  logger = module.logger = bunyan.createLogger logging-opts
  return done!


global.get-logger = GET_LOGGER