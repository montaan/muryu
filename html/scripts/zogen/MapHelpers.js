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




Loader = function(map) {
  this.map = map
  this.queue = new PriorityQueue()
  this.tileInfoManager = new TileInfoManager(map)
  var t = this
  this.loader = function(completed){
    var tile = this.tile || this
    delete t[tile.uuid]
    delete tile.loader
    this.removeEventListener("load", t.loader, true)
    this.removeEventListener("abort", t.loader, true)
    this.removeEventListener("error", t.loader, true)
    if (completed) t.totalCompletes++
    t.loads--
    t.process()
  }
}
Loader.prototype = {
  totalLoads : 0,
  totalRequests : 0,
  totalCancels : 0,
  totalCompletes : 0,

  loads : 0,
  maxLoads : 8,
  tileSize : 0.125, // in Mbps
  bandwidthLimit : -2.0, // in Mbps, negative values for no limit

  load : function(dZ, dP, tile) {
    this[tile.uuid] = tile
    this.queue.insert(tile, [dZ, dP])
    this.totalRequests++
    this.process()
  },

  process : function() {
    while ((this.loads < this.maxLoads) && !this.queue.isEmpty()) {
      var tile = this.queue.shift()
      tile.loader = this.loader
      tile.addEventListener("load", this.loader, true)
      tile.addEventListener("abort", this.loader, true)
      tile.addEventListener("error", this.loader, true)
      this.loads++
      var t = this
      if (this.bandwidthLimit > 0) {
        setTimeout(function(){
          tile.load(t.tileInfoManager)
        }, 1000 * ((this.tileSize * this.maxLoads) / this.bandwidthLimit))
      } else {
        setTimeout(function(){
          tile.load(t.tileInfoManager)
        }, 0)
        // hack to make zooming out a bit less of a pain
        // if zooming out and answering queries instantly from cache
      }
      this.totalLoads++
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




TileInfoManager = function(map) {
  this.map = map
  this.request_bundle = []
  this.cache = {}
  var t = this
  this.sendBundle = function(){
    t.bundleSender()
  }
}
TileInfoManager.prototype = {

  callbackDelay : 50,
  cacheZ : 5,

  server : '/tile_info',

  flushCache : function() {
    this.cache = {}
  },

  requestInfo : function(x,y,z, callback) {
    var rv = this.getCachedInfo(x,y,z)
    if (rv && callback.handleInfo)
      callback.handleInfo(rv)
    else
      this.bundleRequest(arguments)
  },

  getCachedInfo : function(x,y,z) {
    var zc = this.cache[z]
    var c = zc && zc[x+':'+y]
    if (c) {
      return c
    } else if (z > this.cacheZ) {
      if (!this.cache[this.cacheZ]) return false
      var zf = 1 << (z-this.cacheZ)
      var rzf = 1.0 / zf
      var rx = x * rzf
      var ry = y * rzf
      var rsz = this.map.tileSize * rzf
      var xz = Math.floor(rx / this.map.tileSize) * this.map.tileSize
      var yz = Math.floor(ry / this.map.tileSize) * this.map.tileSize
      var tz = this.cache[this.cacheZ][xz+':'+yz]
      if (!tz) return false
      var res = []
      var rrx = rx - xz
      var rry = ry - yz
      for (var i=0; i<tz.length; i++) {
        var a = tz[i]
        if (!(a.x+a.sz < rrx || a.y+a.sz < rry || a.x >= rrx+rsz || a.y >= rry+rsz)) {
          var na = Object.extend({}, a)
          na.x = (a.x - rrx) * zf
          na.y = (a.y - rry) * zf
          na.sz *= zf
          res.push(na)
        }
      }
      if (!this.cache[z]) this.cache[z] = {}
      this.cache[z][x+':'+y] = res
      return res
    } else {
      return false
    }
  },

  bundleRequest : function(req) {
    this.request_bundle.push(req)
    if (this.requestTimeout) clearTimeout(this.requestTimeout)
    this.requestTimeout = setTimeout(this.sendBundle, 10)
  },

  bundleSender : function() {
    var reqs = []
    var callbacks = []
    var reqb = this.request_bundle
    this.request_bundle = []
    var tsz = this.map.tileSize
    for (var i=0; i<reqb.length; i++) {
      var req = reqb[i]
      var info = this.getCachedInfo(req[0], req[1], req[2])
      if (!info) {
        if (req[2] >= this.cacheZ) {
          var rz = 1 << (req[2]-this.cacheZ)
          reqs.push([Math.floor(req[0]/rz/tsz) * tsz, Math.floor(req[1]/rz/tsz) * tsz, this.cacheZ])
        } else {
          reqs.push(req.slice(0,3))
        }
        callbacks.push(req)
      } else {
        this.callbackHandler(req)
      }
    }
    reqs = reqs.uniq()
    var t = this
    var parameters = {}
    parameters.tiles = Object.toJSON(reqs)
    if (this.map.query)
      parameters.q = this.map.query
    if (this.map.time)
      parameters.time = this.map.time
    new Ajax.Request(this.server, {
      method : 'post',
      parameters : parameters,
      onSuccess : function(res) {
        var infos = res.responseText.evalJSON()
        for (var i=0; i<reqs.length; i++) {
          var info = infos[i]
          var req = reqs[i]
          if (!t.cache[req[2]])
            t.cache[req[2]] = {}
          t.cache[req[2]][req[0]+':'+req[1]] = info
        }
        // everything cached, let's retry getCachedInfo
        for (var i=0; i<callbacks.length; i++) {
          t.callbackHandler(callbacks[i])
        }
      },
      onFailure : function(res) {
        for (var i=0; i<callbacks.length; i++) {
          var callback = callbacks[i]
          if (callback[3].handleInfo)
            callback[3].handleInfo(false)
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
      if (callback[3].handleInfo) {
        var info = t.getCachedInfo.apply(t, callback)
        callback[3].handleInfo(info)
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
