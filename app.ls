#!/usr/bin/env lsc
#
require! <[fs path]>
require! <[colors yargs prettyjson]>
moment = require \moment-timezone
YAML = require \js-yaml

# When the entry script is /xxx/sensor-hub/app.ls, then
# use `/xxx/sensor-hub` as working directory.
#
# When the entry script is /xxx/sensor-hub/app/index.js (or index.raw.js),
# then still use `/xxx/sensor-hub` as working directory.
#
entry = path.basename process.argv[1]
current-dir = path.dirname process.argv[1]
current-dir = path.dirname current-dir unless entry is \app.ls

global.app-context =
  current-dir: current-dir
  work-dir: "#{current-dir}/work"
  log-dir: "#{current-dir}/logs"
  boot-time: moment! .format 'YYYYMM'


ERR_EXIT = (message) ->
  console.error message
  return process.exit 0

LOAD_CONFIG = (file, done) ->
  (err, buffer) <- fs.readFile file, \utf8
  return done err if err?
  try
    config = YAML.safeLoad buffer.toString!
    return done null, config
  catch error
    return done error


argv = yargs
  .alias \c, \config
  .describe \c, 'the config name to be loaded from APP_DIR/config/NAME.yml'
  .default \c, \default
  .demandOption <[config]>
  .strict!
  .help!
  .argv


config-file = "#{__dirname}/config/#{argv.config}.yml"
(stats-err, stats) <- fs.stat config-file
return ERR_EXIT "no such config file: #{config-file}, err: #{stats-err}" if stats-err?
console.error "loading configuration from #{config-file.cyan} ..."
(load-err, config) <- LOAD_CONFIG config-file
return ERR_EXIT "failed to load config #{config-file}, err: #{load-err}" if load-err?
console.error "initialize config successfully, config =>"
text = prettyjson.render config, do
  keysColor: \gray
  dashColor: \green
  stringColor: \yellow
  numberColor: \cyan
  defaultIndentation: 4
xs = text.split '\n'
[ console.error "\t#{x}" for x in xs ]
console.error ""
logger = require \./lib/logger
(logger-err) <- logger.init config[\logger]
return ERR_EXIT "failed to initialize logger, err: #{logger-err}" if logger-err?
console.error "initialize logger successfully"
application = require \./lib/application
(init-err) <- application.init config
return ERR_EXIT "failed to initialize application, err: #{init-err}" if init-err?
return