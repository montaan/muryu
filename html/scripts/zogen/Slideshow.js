Tr.addTranslations('en-US', {
  'Slideshow' : 'Slideshow'
})
Tr.addTranslations('fi-FI', {
  'Slideshow' : 'Kuvaesitys'
})

Slideshow = function(container){
  this.infos = {}
  this.container = container
  this.setupElements()
  this.animate()
}
Slideshow.make = function(idx, query) {
  var e = E('div', null, null, null, {
    width: '640px',
    height: '480px'
  })
  var w = new Desk.Window(e, {'title':Tr('Slideshow'),'transient':true})
  w.slideshow = new Slideshow(e)
  w.addListener('resize', function(ev) {
    if (e.style.width != w.contentElement.style.width)
      e.style.width = w.contentElement.style.width
    if (e.style.height != w.contentElement.style.height)
      e.style.height = w.contentElement.style.height
    w.slideshow.resize()
  })
  w.slideshow.listURL = '/items'
  w.slideshow.filePrefix = '/files/'
  w.slideshow.query = {}
  if (query)
    w.slideshow.query.q = query
  w.slideshow.showIndex(idx)
  return w
}

var CanvasSlideshow = {

  width: 600,
  height: 400,
  
  frameDuration : 15,
  blendDuration : 500,

  setupElements : function() {
    this.element = E('div',null,null,'slideshow', {
      display: 'block',
      position: 'absolute'
    })
    this.element.addEventListener('click', function(ev) {
      if (Event.isLeftClick(ev)) {
        if (ev.layerX < ev.target.offsetWidth/2)
          this.prev()
        else
          this.next()
      }
      return true
    }.bind(this), false)
    this.currentCanvas = this.makeCanvas()
    this.nextCanvas = this.makeCanvas()
    this.viewCanvas = this.makeCanvas()
    this.viewCanvas.style.position = 'absolute'
    this.viewCanvas.style.zIndex = 0
    this.loadingIndicator = E('div',null,null,'loading', {
      display: 'block',
      position: 'absolute',
      visibility: 'hidden',
      left: '0px',
      top: '0px',
      width: '4px',
      height: '12px',
      backgroundColor: 'red',
      zIndex: 1
    })
    this.element.appendChild(this.loadingIndicator)
    this.element.appendChild(this.viewCanvas)
    this.resize()
    this.container.appendChild(this.element)
  },
  
  animate : function() {
    this.curveBlend = this.sinewaveBlend
    this.animationInterval = setInterval(this.animationStep.bind(this), this.frameDuration)
  },
  
  animationStep : function() {
    if (this.needRefresh) {
      this.skipBlend = true
      this.show(this.getLoadingImage().src)
      this.needRefresh = false
    }
    if (this.updateNextCanvas && !this.blendStart) {
      this.nextCanvas.ctx.clearRect(0,0,this.nextCanvas.width,this.nextCanvas.height)
      this.nextCanvas.ctx.drawImage(this.loadingImage, 
        0, 0,
        this.nextCanvas.width, this.nextCanvas.height)
      this.updateNextCanvas = false
    }
    if (this.blending && !this.loading) {
      if (!this.blendStart) {
        this.blendStart = new Date().getTime()
        this.viewCanvas.width = Math.max(this.nextCanvas.width, this.currentCanvas.width)
        this.viewCanvas.height = Math.max(this.nextCanvas.height, this.currentCanvas.height)
        this.viewCanvas.style.left = Math.floor((this.width-this.viewCanvas.width)/2) + 'px'
        this.viewCanvas.style.top = Math.floor((this.height-this.viewCanvas.height)/2) + 'px'
      }
      var elapsed = new Date().getTime() - this.blendStart
      var blendFactor = (elapsed / this.blendDuration)
      if (this.skipBlend || elapsed >= this.blendDuration) {
        this.blending = false
        blendFactor = 1.0
        this.blendStart = false
      }
      var curvedFactor = Math.max(0, Math.min(1, this.curveBlend(blendFactor)))
      if (isNaN(curvedFactor))
        curvedFactor = 1.0
      var c = this.viewCanvas.ctx
      c.clearRect(0,0,this.viewCanvas.width,this.viewCanvas.height)
      if (!this.skipBlend) {
        c.globalAlpha = 1.0 - curvedFactor
        this.drawImageCentered(this.viewCanvas, this.currentCanvas)
      }
      c.globalAlpha = curvedFactor
      this.drawImageCentered(this.viewCanvas, this.nextCanvas)
      c.globalAlpha = 1.0
      if (!this.blending) {
        var tmp = this.currentCanvas
        this.currentCanvas = this.nextCanvas
        this.nextCanvas = tmp
      }
      this.skipBlend = false
    }
  },
  
  drawImageCentered : function(canvas, image) {
    canvas.ctx.drawImage(image,
      0, 0, 
      image.width, image.height,
      Math.floor((canvas.width-image.width)/2), Math.floor((canvas.height-image.height)/2), 
      image.width, image.height)
  },
  
  sinewaveBlend : function(fac) {
    return 0.5 - (0.5 * Math.cos(fac*Math.PI))
  },
  
  show : function(url) {
    if (url) {
      this.load(url)
      this.blending = true
    }
  },
  
  next : function(idx) {
    this.seek(1)
  },

  prev : function(idx) {
    this.seek(-1)
  },
  
  seek : function(dir, amt) {
    if (amt == undefined) amt = 1
    var ni = this.index + dir*amt
    if (ni < 0 && this.itemCount) ni = this.itemCount+ni
    if (this.itemCount && ni >= this.itemCount) ni -= this.itemCount
    this.showIndex(ni, dir)
  },
  
  showIndex : function(idx, dir) {
    if (idx < 0 && idx >= this.itemCount) return
    if (dir == undefined) dir = 1
    var params = Object.clone(this.query)
    this.index = idx
    if (this.infos[idx]) {
      var info = this.infos[idx]
      if (info.deleted == 't' || !['jpeg','jpg','png','gif'].include( info.path.split(".").last().toString().toLowerCase() ))
        this.seek(dir, 1)
      else
        this.show(this.filePrefix + info.path)
    } else {
      var f = Math.max(0, idx - 100)
      var l = idx + 100
      params.first = f
      params.last = l
      new Ajax.Request(this.listURL, {
        parameters : params,
        onSuccess : function(res) {
          var infos = res.responseText.evalJSON()
          this.itemCount = infos.itemCount
          for (var i=0; i<infos.items.length; i++) {
            var info = infos.items[i]
            this.infos[info.index] = info
          }
          if (this.infos[this.index])
            this.showIndex(this.index)
        }.bind(this)
      })
    }
  },
  
  load : function(url) {
    if (this.getLoadingImage().src == url && !this.loading) {
      this.getLoadingImage().onload()
    } else {
      this.getLoadingImage().src = url
      this.loadingIndicator.style.visibility = 'visible'
      this.loading = true
    }
  },
  
  onload : function() {
    this.loadingIndicator.style.visibility = 'hidden'
    this.loading = false
  },
  
  makeCanvas : function() {
    var c = E('canvas')
    c.imageWidth = 0
    c.imageHeight = 0
    c.ctx = c.getContext('2d')
    return c
  },
  
  resize : function() {
    this.width = this.container.offsetWidth
    this.height = this.container.offsetHeight
    this.element.style.width = this.width + 'px'
    this.element.style.height = this.height + 'px'
    this.needRefresh = true
  },
  
  getLoadingImage : function() {
    if (!this.loadingImage) {
      this.loadingImage = new Image()
      var t = this
      this.loadingImage.onload = function() {
        var rw = this.width
        var rh = this.height
        if (rw > t.width) {
          rh = Math.floor(rh * (t.width / rw))
          rw = t.width
        }
        if (rh > t.height) {
          rw = Math.floor(rw * (t.height / rh))
          rh = t.height
        }
        t.nextCanvas.width = Math.floor(rw)
        t.nextCanvas.height = Math.floor(rh)
        t.updateNextCanvas = true
        t.onload()
      }
    }
    return this.loadingImage
  }
  
}


Slideshow.prototype = CanvasSlideshow
