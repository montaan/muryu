ImagePool = function() {
  this.pool = []
}
ImagePool.getPool = function() {
  if (!ImagePool.pool)
    ImagePool.pool = new ImagePool()
  return ImagePool.pool
}
ImagePool.prototype = {

  get : function() {
    if (this.pool.length == 0) {
      this.pool.push(document.createElement("img"))
    }
    return this.pool.shift()
  },

  put : function(img) {
    this.pool.push(img)
  }

}




Loader = function() {
  this.queue = new PriorityQueue()
  this.tileInfoManager = new TileInfoManager()
  var t = this
  this.loader = function(completed){
    var tile = this.tile || this
    delete t[tile.uuid]
    delete tile.loader
    this.removeEventListener("load", t.loader, true)
    this.removeEventListener("abort", t.loader, true)
    this.removeEventListener("error", t.loader, true)
    t.loads--
    if (completed) t.totalCompletes++
    t.process()
  }
}
Loader.prototype = {
  maxLoads : 2,
  loadsEnabled : true,
  tileSize : 0.125, // in Mbps
  bandwidthLimit : -2.0, // in Mbps, negative values for no limit

  totalLoads : 0,
  totalRequests : 0,
  totalCancels : 0,
  totalCompletes : 0,

  loads : 0,
  __maxLoads : 1,
  initialLoad : true,

  load : function(dZ, dP, tile) {
    this[tile.uuid] = tile
    this.queue.insert(tile, [dZ, dP])
    this.totalRequests++
    this.process()
  },

  requestInfo : function() {
    this.tileInfoManager.requestInfo.apply(this.tileInfoManager, arguments)
  },

  process : function() {
    while (this.loadsEnabled && (this.loads < this.__maxLoads) && !this.queue.isEmpty()) {
      if (this.initializationTimeout) {
        clearTimeout(this.initializationTimeout)
        this.initializationTimeout = false
      }
      var tile = this.queue.shift()
      tile.loader = this.loader
      tile.addEventListener("load", this.loader, true)
      tile.addEventListener("abort", this.loader, true)
      tile.addEventListener("error", this.loader, true)
      this.loads++
      if (this.bandwidthLimit > 0) {
        // THIS IS function(){}.bind(tile) BECAUSE JAVASCRIPT HAS CALL-BY-NAME, DO NOT CHANGE
        // (unless you wish to spend an hour debugging seemingly randomly non-loading tiles)
        setTimeout(function(){
          this.load()
        }.bind(tile), 1000 * ((this.tileSize * this.maxLoads) / this.bandwidthLimit))
      } else {
        // THIS IS function(){}.bind(tile) BECAUSE JAVASCRIPT HAS CALL-BY-NAME, DO NOT CHANGE
        // (unless you wish to spend an hour debugging seemingly randomly non-loading tiles)
        setTimeout(function(){
          this.load()
        }.bind(tile), 0) // hack to make zooming out a bit less of a pain
                         // if zooming out and answering queries instantly from cache
      }
      this.totalLoads++
      // First tile load is done separately, the rest with maxLoads parallel loads.
      // What this aims to do is minimize first tile latency and increase throughput for the rest.
      //
      // The idea is to give information required to continue navigation ASAP, then fill out
      // the rest of the picture. Locus is on pointer => load tile under pointer straight away,
      // then load the surrounding tiles in parallel while the eye is still fixated on the first tile.
      if (this.initialLoad) { 
        this.__maxLoads = 1
        this.initialLoad = false
      } else {
        this.__maxLoads = this.maxLoads
      }
    }
    if (this.queue.isEmpty()) {
      var t = this
      t.initializationTimeout = setTimeout(function(){
        t.initialLoad = true
        t.initializationTimeout = false
      }, 1000)
    }
  },
  
  cancel : function(tile) {
    var lt = this[tile.uuid]
    if (lt) {
      delete this[tile.uuid]
      this.queue.remove(lt)
      this.totalCancels++
    }
  },
  
  flushCache : function() {
    this.tileInfoManager.flushCache()
  }

}




TileInfoManager = function() {
  this.bundles = {}
  this.cache = {}
  this.keys = []
  var t = this
  this.sendBundles = function(){
    for (var i=0; i<t.keys.length; i++) {
      var key = t.keys[i]
      t.bundleSender(key, t.bundles[key])
      var reqnum = t.bundles[key].requestNumber
      t.bundles[key] = []
      t.bundles[key].requestNumber = reqnum
      t.bundles[key].firstAt = new Date().getTime()
    }
  }
}
TileInfoManager.prototype = {

  callbackDelay : 50,
  cacheZ : 5,

  flushCache : function() {
    this.cache = {}
  },

  requestInfo : function(server, x,y,z, callback) {
    var rv = this.getCachedInfo(server, x,y,z)
    if (rv && callback.handleInfo)
      callback.handleInfo(rv)
    else
      this.bundleRequest(arguments)
  },

  getCachedInfo : function(key, x,y,z) {
    if (x < 0 || y < 0) return []
    if (!this.cache[key])
      this.cache[key] = {}
    var qcache = this.cache[key]
    var zc = qcache[z]
    var c = zc && zc[x+':'+y]
    if (c) {
      return c
    } else if (z > this.cacheZ) {
      if (!qcache[this.cacheZ]) return false
      var zf = 1 << (z-this.cacheZ)
      var rzf = 1.0 / zf
      var rx = x * rzf
      var ry = y * rzf
      var rsz = 256 * rzf
      var xz = Math.floor(rx / 256) * 256
      var yz = Math.floor(ry / 256) * 256
      var tz = qcache[this.cacheZ][xz+':'+yz]
      if (!tz) return false
      var res = []
      var rrx = rx - xz
      var rry = ry - yz
      for (var i=0; i<tz.length; i++) {
        var a = tz[i]
        if (!(a.x+a.sz < rrx || a.y+a.sz < rry || a.x >= rrx+rsz || a.y >= rry+rsz)) {
          var na = Object.clone(a)
          na.x = (a.x - rrx) * zf
          na.y = (a.y - rry) * zf
          na.sz *= zf
          res.push(na)
        }
      }
      if (!qcache[z]) qcache[z] = {}
      qcache[z][x+':'+y] = res
      return res
    } else {
      return false
    }
  },

  bundleRequest : function(req) {
    var key = req[0]
    if (!this.keys[key]) {
      this.bundles[key] = []
      this.bundles[key].firstAt = 0
      this.bundles[key].requestNumber = 0
      this.keys[key] = true
      this.keys.push(key)
    }
    this.bundles[key].push(req)
    if (this.requestTimeout) clearTimeout(this.requestTimeout)
    if (this.bundles[key].length == 1 && new Date().getTime() - this.bundles[key].firstAt > 1000) {
      this.sendBundles()
      this.bundles[key].firstAt = new Date().getTime()
      this.bundles[key].requestNumber = 0
    } else if (this.bundles[key].requestNumber < 4) {
      this.bundles[key].requestNumber++
      this.sendBundles()
    } else if (this.bundles[key].length == 4) {
      this.bundles[key].requestNumber++
      this.sendBundles()
    } else {
      this.requestTimeout = setTimeout(this.sendBundles, 150)
    }
  },

  bundleSender : function(server, bundle) {
    var reqs = []
    var callbacks = []
    var reqb = bundle
    var tsz = 256
    for (var i=0; i<reqb.length; i++) {
      var req = reqb[i]
      var info = this.getCachedInfo(req[0], req[1], req[2], req[3])
      if (!info) {
        if (req[3] >= this.cacheZ) {
          var rz = 1 << (req[3]-this.cacheZ)
          reqs.push([Math.floor(req[1]/rz/tsz) * tsz, Math.floor(req[2]/rz/tsz) * tsz, this.cacheZ])
        } else {
          reqs.push(req.slice(1,3))
        }
        callbacks.push(req)
      } else {
        this.callbackHandler(req)
      }
    }
    if (reqs.length == 0) return
    var t = this
    var parameters = server.split("?")[1].toQueryParams()
    parameters.tiles = '[' + reqs.invoke('toJSON').uniq().join(",") + ']'
    reqs = parameters.tiles.evalJSON()
    new Ajax.Request(server.split("?")[0], {
      method : 'post',
      parameters : parameters,
      onSuccess : function(res) {
        var infos = res.responseText.evalJSON()
        for (var i=0; i<reqs.length; i++) {
          var info = infos[i]
          var req = reqs[i]
          if (!t.cache[server])
            t.cache[server] = {}
          if (!t.cache[server][req[2]])
            t.cache[server][req[2]] = {}
          t.cache[server][req[2]][req[0]+':'+req[1]] = info
        }
        // everything cached, let's retry getCachedInfo
        for (var i=0; i<callbacks.length; i++) {
          t.callbackHandler(callbacks[i])
        }
      },
      onFailure : function(res) {
        for (var i=0; i<callbacks.length; i++) {
          var callback = callbacks[i]
          if (callback[4].handleInfo)
            callback[4].handleInfo(false)
        }
      }
    })
    this.requestTimeout = false
  },

  callbackHandler : function(callback) {
    setTimeout(this.makeCallbackHandler(callback), this.callbackDelay)
  },

  makeCallbackHandler : function(callback) {
    var t = this
    return function(){
      if (callback[4].handleInfo) {
        var info = t.getCachedInfo.apply(t, callback)
        callback[4].handleInfo(info)
      }
    }
  }

}





PriorityQueue = function(){
  this.queue = []
}
PriorityQueue.prototype = {

  insert : function(item, priority) {
    for (var i=0; i<this.queue.length; i++) {
      if (this.queue[i].priority[0] > priority[0] ||
          (this.queue[i].priority[0] == priority[0] &&
          this.queue[i].priority[1] > priority[1])
      ) {
        this.queue.splice(i,0, {priority: priority, value: item})
        return
      }
    }
    this.queue.push({priority: priority, value: item})
  },

  remove : function(item) {
    for (var i=0; i<this.queue.length; i++) {
      if (this.queue[i].value.uuid == item.uuid) {
        this.queue.splice(i,1)
        return
      }
    }
  },

  shift : function() {
    if (this.queue.length == 0) return false
    return this.queue.shift().value
  },

  isEmpty : function() {
    return this.queue.length == 0
  }

}
