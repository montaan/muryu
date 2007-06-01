Slideshow = function(container){
  this.container = container
  this.setupElements()
  this.animate()
}
Slideshow.make = function() {
  var e = E('div', null, null, null, {
    width: '640px',
    height: '480px'
  })
  var w = new Desk.Window(e, {'title':'slideshow','transient':true,'group':'slideshow'})
  w.slideshow = new Slideshow(e)
  w.addListener('resize', function(ev) {
    if (e.style.width != w.contentElement.style.width)
      e.style.width = w.contentElement.style.width
    if (e.style.height != w.contentElement.style.height)
      e.style.height = w.contentElement.style.height
    w.slideshow.resize()
  })
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
    this.currentCanvas = this.makeCanvas()
    this.nextCanvas = this.makeCanvas()
    this.viewCanvas = this.makeCanvas()
    this.viewCanvas.style.zIndex = 0
    this.loadingIndicator = E('div',null,null,'loading', {
      display: 'block',
      position: 'absolute',
      visibility: 'hidden',
      left: '0px',
      top: '0px',
      width: '4px',
      height: '16px',
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
      this.nextCanvas.ctx.clearRect(0,0,this.width,this.height)
      this.nextCanvas.ctx.drawImage(this.loadingImage, 
        0, 0,
        this.nextCanvas.imageWidth, this.nextCanvas.imageHeight)
      this.updateNextCanvas = false
    }
    if (this.blending && !this.loading) {
      if (!this.blendStart)
        this.blendStart = new Date().getTime()
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
      c.clearRect(0,0,this.width, this.height)
      if (!this.skipBlend) {
        c.globalAlpha = 1.0 - curvedFactor
        this.drawImageCentered(c, this.currentCanvas)
      }
      c.globalAlpha = curvedFactor
      this.drawImageCentered(c, this.nextCanvas)
      c.globalAlpha = 1.0
      if (!this.blending) {
        var tmp = this.currentCanvas
        this.currentCanvas = this.nextCanvas
        this.nextCanvas = tmp
      }
      this.skipBlend = false
    }
  },
  
  drawImageCentered : function(ctx, canvas) {
    if (canvas.imageWidth) {
      ctx.drawImage(canvas,
        0, 0, 
        canvas.imageWidth, canvas.imageHeight,
        (this.width-canvas.imageWidth)/2, (this.height-canvas.imageHeight)/2, 
        canvas.imageWidth, canvas.imageHeight)
    }
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
    c.ctx = c.getContext('2d')
    return c
  },
  
  resize : function() {
    this.width = this.container.offsetWidth
    this.height = this.container.offsetHeight
    this.element.style.width = this.width + 'px'
    this.element.style.height = this.height + 'px'
    this.resizeCanvas(this.currentCanvas)
    this.resizeCanvas(this.nextCanvas)
    this.resizeCanvas(this.viewCanvas)
    this.needRefresh = true
  },
  
  resizeCanvas : function(c) {
    c.width = this.width
    c.height = this.height
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
        t.nextCanvas.imageWidth = rw
        t.nextCanvas.imageHeight = rh
        t.updateNextCanvas = true
        t.onload()
      }
    }
    return this.loadingImage
  }
  
}


Slideshow.prototype = CanvasSlideshow
