Session = {}
Object.extend(Session, EventListener)
try {
  Session.storage = globalStorage[location.hostname]
} catch(e) {}
Session.objects = []
Session.load = function(name) {
  if (!name) name = 'session'
  var sessionString = this.storage.getItem(name)
  this.newEvent('init')
  if (sessionString) {
    var session = sessionString.value.evalJSON()
    session.each(this.loadDump)
    return true
  }
  return false
}
Session.loadDump = function(dump) {
  var loader = Object.retrieve(dump.loader)
  return loader.loadSession(dump.data)
}
Session.save = function(name) {
  if (!name) name = 'session'
  if (!this.objects || this.objects.isEmpty()) return
  var session = Object.toJSON(this.objects.invoke('dumpSession'))
  var rv = this.storage.setItem(name, session)
  this.newEvent('save')
  return rv
}
Session.clear = function(name, reload) {
  if (!name) name = 'session'
  this.objects = []
  var rv = this.storage.removeItem(name)
  this.newEvent('clear')
  if (reload != false) document.location.reload()
  return rv
}
Session.add = function(o){  
  this.objects.push(o) 
  this.newEvent('add', {value:o})
}
Session.remove = function(o){ 
  this.objects.deleteFirst(o) 
  this.newEvent('remove', {value:o})
}
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