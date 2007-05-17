Session = {}
try {
  Session.storage = globalStorage[location.hostname]
} catch(e) {}
Session.objects = []
Session.load = function(name) {
  if (!name) name = 'session'
  var sessionString = this.storage.getItem(name)
  if (sessionString) {
    var session = sessionString.value.evalJSON()
    session.each(this.loadDump)
    return true
  }
  return false
}
Session.loadDump = function(dump) {
  var loader = dump.loader.split(".").inject(
    window,
    function(o,n){return o[n]}
  )
  return loader.loadSession(dump.data)
}
Session.save = function(name) {
  if (!name) name = 'session'
  if (!this.objects || this.objects.isEmpty()) return
  var session = Object.toJSON(this.objects.invoke('dumpSession'))
  return this.storage.setItem(name, session)
}
Session.clear = function(name) {
  if (!name) name = 'session'
  this.objects = []
  return this.storage.removeItem(name)
}
Session.add = function(o){ this.objects.push(o) }
Session.remove = function(o){ this.objects.deleteFirst(o) }
Session.makeDumpable = function(obj) {
  if (!obj.prototype.dumpSession) {
    obj.prototype.dumpSession = function() {
      return {
        loader : this.loader,
        data : null
      }
    }
  }
  if (!obj.loadSession) {
    obj.loadSession = function(data) {
      return new this(data)
    }
  }
}