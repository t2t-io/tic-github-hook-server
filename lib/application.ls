require! <[github-webhook-handler http async fs byline mkdirp path]>
{DBG, ERR, WARN, INFO} = global.get-logger __filename
moment = require \moment-timezone
{spawn} = require \child_process


class RepositoryHook
  (@name, @opts) ->
    {script} = opts
    @script = script
    return

  init: (done) ->
    {name, script} = self = @
    return done "missing script for #{name}" unless script?
    return done!

  process-push: (id, payload) ->
    {name, script} = self = @
    {repository, ref} = payload
    {full_name} = repository
    prefix = "[#{full_name.cyan}:#{id.gray}]"
    now = moment!
    fullpath = "/tmp/github-hooks/#{name}/#{now.format 'YYYYMMDD-HHmmss'}-#{id}.json"
    INFO "#{prefix}: creating directory for #{fullpath}"
    (mkdirp-err) <- mkdirp path.dirname fullpath
    return ERR mkdirp-err if mkdirp-err?
    (write-err) <- fs.writeFile fullpath, (JSON.stringify payload)
    return ERR write-err if write-err?
    xs = ref.split '/'
    return unless xs.length >= 2
    [x, reference-type, reference] = xs
    if reference-type is \heads and reference is \master
      category = \_
      app = \_
      version = \master
    else if reference-type is \tags
      tokens = reference.split '-'
      category = tokens.shift!
      version = tokens.pop!
      app = tokens.join '-'
    else
      return WARN "#{prefix}: cannot handle this ref: #{ref}"
    INFO "#{prefix}: push #{reference-type}/#{reference.gray} => #{category}/#{app} with version #{version}"
    pp = "#{prefix}[#{category.gray}:#{app.green}:#{version.magenta}]"
    cwd = process.cwd!
    args = [name, "push", reference-type, fullpath, category, app, version]
    opts = cwd: cwd, env: process.env, stdio: <[pipe pipe]>
    p = spawn script, args, opts
    p.on \error, (err) -> return ERR "#{pp}: push #{xs[1]}/#{xs[2].gray}, failed: #{err}"
    p.on \exit, (exit) -> return INFO "#{pp}: #{script.yellow} #{(args.join ' ').gray} => exit: #{exit}"
    stdout-reader = byline p.stdout
    stderr-reader = byline p.stderr
    stdout-reader.on \data, (line) -> INFO "#{pp}: #{'out'.gray}: #{line}"
    stderr-reader.on \data, (line) -> INFO "#{pp}: #{'err'.red}: #{line.to-string!.red}"



class Application
  (@opts) ->
    @hooks = []
    @hook-map = {}
    return

  init: (done) ->
    {opts} = self = @
    {host, port} = opts.http
    self.hooks = hooks = [ (new RepositoryHook k, v) for k, v of opts.repositories ]
    self.hook-map = { [h.name, h] for h in hooks }
    for h in hooks
      INFO "add repository #{h.name.cyan} with script #{h.script.yellow}"
    f = (h, cb) -> return h.init cb
    (init-err) <- async.eachSeries hooks, f
    return done init-err if init-err?
    handler = self.handler = github-webhook-handler opts.github
    handler.on \error, (err) -> return self.at-error err
    handler.on \push, (evt) -> return self.at-github-push evt
    server = self.server = http.createServer (req, res) -> return self.at-http req, res
    server.on \listening, ->
      INFO "listening #{host}:#{port}"
      return done!
    server.listen port, host

  at-http: (req, res) ->
    (err) <- @handler req, res
    res.statusCode = 404
    res.end "no such location, err: #{err}"

  at-error: (error) ->
    ERR error

  at-github-push: (evt) ->
    {id, payload} = evt
    {hook-map} = self = @
    {name} = payload.repository
    h = hook-map[name]
    return WARN "at-github-push(): no such hook handler for repository #{name.yellow}" unless h?
    return h.process-push id, payload




export init = (opts, done) ->
  app = new Application opts
  return app.init done
