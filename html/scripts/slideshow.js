Tr.addTranslations('en-US', {
  'Slideshow' : 'Slideshow',
  'Reader' : 'Reader'
})
Tr.addTranslations('fi-FI', {
  'Slideshow' : 'Kuvaesitys',
  'Reader' : 'Lukija'
})

// config object should have index, images, container
// can also have fillWindow, pollForNewImages, changeDocumentTitle
Suture = function(config) {
  Object.extend(this, config)
  if (this.window && this.window.parameters)
    Object.extend(this, this.window.parameters)
  var startprog = this.autoProgress
    
  this.root = E("div", this.template, 'slideshow-root')
  var el = $(this.root)
  this.container.appendChild(this.root)
  var rcs = $(this.root).getComputedStyle()
  var wm = parseInt(rcs.marginLeft) + parseInt(rcs.marginRight)
  var hm = parseInt(rcs.marginTop) + parseInt(rcs.marginBottom)
  this.root.style.width = this.container.clientWidth - wm + 'px'
  this.root.style.height = this.container.clientHeight - hm + 'px'

  this.display = el.$("slideshow-display")
  this.display.style.width = this.root.clientWidth - 24 + 'px'
  this.display.style.height = this.root.clientHeight - 52 + 'px'
  this.visibleImage = new FaderDiv(el.$("slideshow-image-1"))
  this.hiddenImage = new FaderDiv(el.$("slideshow-image-2"))
  
  this.loadingIndicator = el.$("slideshow-loading")
  this.nameElement = el.$("slide-name")
  this.nameElement.addEventListener("click", function(ev) {
    if (Event.isLeftClick(ev)) {
      Event.stop(ev)
      new Desk.Window(this.href.replace("files", "items")+"/json")
    }
  }, false)
  this.indexElement = el.$("slideshow-index")
  this.searchIndexElement = el.$("slideshow-search-index")

  this.autoProgressElement = el.$("slideshow-play")
  this.stopAutoProgress()
  this.autoProgressElement.addEventListener("click", this.bind('toggleAutoProgress'), false)

  this.slideDelayElement = el.$("slideshow-slidedelay")
  this.setAutoProgressDelay(this.autoProgressDelay)
  this.slideDelayElement.addEventListener("mousedown", function(ev){ Event.stop(ev) }, false)
  this.slideDelayElement.addEventListener("mouseup", this.bind('autoProgressDelayClickHandler'), false)

  this.slideDelayMinusElement = el.$("slideshow-slidedelay-minus")
  this.slideDelayMinusElement.addEventListener("mousedown", function(ev){ Event.stop(ev) }, false)
  this.slideDelayMinusElement.addEventListener("mouseup", this.bind( 'rotateAutoProgressDelay', -1), false)
  this.slideDelayPlusElement = el.$("slideshow-slidedelay-plus")
  this.slideDelayPlusElement.addEventListener("mousedown", function(ev){ Event.stop(ev) }, false)
  this.slideDelayPlusElement.addEventListener("mouseup", this.bind( 'rotateAutoProgressDelay', 1), false)

  this.slideReverseElement = el.$("slideshow-play-reverse")
  this.setReverseProgress(this.reverseProgress)
  this.setRandomProgress(this.randomProgress)
  this.slideReverseElement.addEventListener("mousedown", function(ev){ Event.stop(ev) }, false)
  this.slideReverseElement.addEventListener("click", this.bind('toggleDirection'), false)

  this.prevHundredElement = el.$("slideshow-prev-100")
  this.prevTenElement = el.$("slideshow-prev-10")
  this.prevElement = el.$("slideshow-prev")
  this.prevHundredElement.addEventListener("mouseup", this.bind('rotate',-100), false)
  this.prevTenElement.addEventListener("mouseup", this.bind('rotate',-10), false)
  this.prevElement.addEventListener("mouseup", this.bind('rotate',-1), false)

  this.randomElement = el.$("slideshow-random")
  this.randomElement.addEventListener("mouseup", this.bind('goToRandom'), false)

  this.nextHundredElement = el.$("slideshow-next-100")
  this.nextTenElement = el.$("slideshow-next-10")
  this.nextElement = el.$("slideshow-next")
  this.nextHundredElement.addEventListener("mouseup", this.bind('rotate',100), false)
  this.nextTenElement.addEventListener("mouseup", this.bind('rotate',10), false)
  this.nextElement.addEventListener("mouseup", this.bind('rotate',1), false)

  this.searchForm = el.$("slideshow-search-form")
  this.searchForm.addEventListener('submit', function(ev) { Event.stop(ev) }, false)
  
  this.search = this.searchForm.q
  this.search.value = this.query.q
  this.previousSearchValue = new String(this.search.value)
  
  this.search.addEventListener("focus", function(){ this.focused = true }, false)
  this.search.addEventListener("blur", function(){ this.focused = false }, false)
  this.search.addEventListener("keypress", this.bind( 'searchKeyHandler'), false)

  this.display.addEventListener("mouseup", this.bind( 'clickHandler'), false)
  this.display.addEventListener("mousemove", this.bind( 'mousemoveHandler'), false)
 
  this.root.addEventListener("keypress", this.bind( 'keyHandler'), false)
  this.root.addEventListener("click", this.bind( 'focus'), true)

  this.help = el.$("slideshow-help")
  this.setHelpOpacity(0)
  this.help_toggle = el.$("slideshow-help-toggle-link")
  this.help_toggle.onclick = function(e){ return false }
  this.help_toggle.addEventListener("click", this.bind( 'toggleHelp'), false)
  
  var t = this
  this.frameIntervalPointer = setInterval(function(e){ t.frameHandler(e) }, this.frameTime)
  this.showIndex(this.index)
  if (startprog)
    this.startAutoProgress()
}
Suture.make = function(w, index, query){
  if (!w.width) w.setSize(600,400)
  var wasShaded = w.shaded
  if (w.shaded) {
    w.shade()
  }
  w.setTitle(Tr('Slideshow'))
  var c = E('div')
  c.style.width = '100%'
  c.style.height = '100%'
  var s = new Suture({
    container: c,
    fillWindow: true,
    index: index,
    query: query,
    listURL : '/items/json',
    filePrefix : '/files/',
    window: w
  })
  w.slideshow = s
  var resizer = function() {
    if (!w.shaded) s.resize()
    if (wasShaded) {
      wasShaded = false
      w.shade()
    }
  }
  w.addListener('resize', resizer)
  var minProg = false
  w.addListener('close', function() {
    minProg = false
    if (s.autoProgressTimer)
      s.toggleAutoProgress()
  })
  w.addListener('minimizeChange', function() {
    if (s.autoProgressTimer) {
      s.toggleAutoProgress()
      minProg = true
    } else if (minProg) {
      s.toggleAutoProgress()
      minProg = false
    }
  })
  w.addListener('containerChange', resizer)
  w.addListener('shadeChange', resizer)
  w.setContent(c)
  return w
}
Suture.makePDF = function(index, path, pages){
  var c = E('div')
  c.style.width = '100%'
  c.style.height = '100%'
  var infos = {}
  for (var i=0; i<pages; i++) {
    infos[i] = {path: path+'/page?number='+(i+1)}
  }
  var s = new Suture({
    container: c,
    fillWindow: true,
    index: index,
    documentFade: true,
    infos: infos,
    query: {q:''},
    itemCount: pages,
    filePrefix : '/files/',
    newQuery : false,
    isSupported : function(){ return true },
    setQuery : function(){ return true }
  })
  return s
}
Suture.loadWindow = function(win, params) {
  document.slideshowWindow = Suture.make(win, win.parameters.index, win.parameters.query)
}
Suture.Reader = function(win, params) {
  if (!win.width) win.setSize(600,400)
  var wasShaded = win.shaded
  if (win.shaded) {
    win.shade()
  }
  win.setTitle(Tr('Reader'))
  var s = Suture.makePDF(win.parameters.index, win.parameters.path, win.parameters.pages)
  s.window = win
  win.slideshow = s
  var resizer = function() {
    if (!win.shaded) s.resize()
    if (wasShaded) {
      wasShaded = false
      win.shade()
    }
  }
  win.addListener('resize', resizer)
  var minProg = false
  win.addListener('close', function() {
    minProg = false
    if (s.autoProgressTimer)
      s.toggleAutoProgress()
  })
  win.addListener('minimizeChange', function() {
    if (s.autoProgressTimer) {
      s.toggleAutoProgress()
      minProg = true
    } else if (minProg) {
      s.toggleAutoProgress()
      minProg = false
    }
  })
  win.addListener('containerChange', resizer)
  win.addListener('shadeChange', resizer)
  win.setContent(s.container)
  return win
}


Suture.prototype = {
  index : 0,
  image : '/transparent.gif',
  fillWindow : false,
  query : null,
  infos : {},
  itemCount : 0,
  listURL : '/items/json',
  filePrefix : '/files/',
  frameTime : 20,
  requestedIndex : null,
  fadeDuration : 500,
  _newSinceLastFocus : 0,
  noSpaceBar : false,
  focused : true,
  fading : false,
  newQuery : true,
  loader : document.createElement("div"),
  indexElement : document.createElement("div"),
  nameElement : document.createElement("div"),
  history : [],
  indexes : null,
  previousSearchValue : "",
  randomProgress : false,
  reverseProgress : false,
  autoProgressDelay : 3,

  bind : function(f) {
    var args = $A(arguments).slice(1)
    var t = this
    if (typeof f == 'string') 
      return function(){ return t[f].apply(t, args.concat($A(arguments))) }
    else
      return function(){ return f.apply(t, args.concat($A(arguments))) }
  },

  setQuery : function(q, loadFirst) {
    this.query = q
    this.infos = {}
    this.newQuery = true
    this.itemCount = 0
    this.previousSearchValue = q.q
    if (loadFirst != false) {
      this.showIndex(0)
    } else if (this.search.value != q.q) { // no loadFirst => didn't come from liveSearch
      this.search.value = q.q
    }
    if (this.window)
      this.window.parameters.query = this.query
  },

  isSupported : function(fn){
    return fn.split(".").last().toString().match(/^(jpe?g|png|gif)$/i)
  },

  rotate : function(offset) {
    this.seek(offset)
  },
  
  seek : function(dir, amt) {
    if (amt == undefined) amt = 1
    var ni = this.index + dir*amt
    if (ni < 0 && this.itemCount) ni = this.itemCount+ni
    if (this.itemCount && ni >= this.itemCount) ni -= this.itemCount
    this.showIndex(ni, dir)
  },
  
  showIndex : function(idx, dir) {
    if (idx < 0 || (idx >= this.itemCount && !this.newQuery)) return
    if (dir == undefined) dir = 1
    this.index = idx
    if (this.window)
      this.window.parameters.index = this.index
    if (this.infos[idx]) {
      var info = this.infos[idx]
      if ((info.deleted == 't' && !this.query.q.match(/\bdeleted:\s*(true|any)\b/i))
          || !this.isSupported(info.path)) {
        if (this.startIdx == undefined) {
          this.startIdx = this.index
        } else if (this.index == this.startIdx) { // no displayable images in set
          this.search.style.background = "#ff0000"
          this.search.style.color = "#ffffff"
          return
        }
        this.seek(dir)
      } else {
        this.startIdx = undefined
        this.request(this.filePrefix + info.path, this.index)
      }
    } else {
      var params = Object.clone(this.query)
      var f = Math.max(0, idx - 100)
      var l = idx + 100
      if (!params.q || params.q.toString().length == 0) delete params.q
      params.first = f
      params.last = l
      this.loadingIndicator.style.visibility = "inherit"
      this.newQuery = false
      new Ajax.Request(this.listURL, {
        parameters : params,
        method : 'get',
        onSuccess : function(res) {
          this.loadingIndicator.style.visibility = "hidden"
          var infos = res.responseText.evalJSON()
          this.itemCount = infos.itemCount
          for (var i=0; i<infos.items.length; i++) {
            var info = infos.items[i]
            this.infos[info.index] = info
          }
          if (this.infos[this.index])
            this.showIndex(this.index)
          if (this.itemCount == 0) {
            this.search.style.background = "#ff0000"
            this.search.style.color = "#ffffff"
          } else {
            this.search.style.background = null
            this.search.style.color = null
          }
        }.bind(this),
        onFailure : function(res) {
          this.loadingIndicator.style.visibility = "hidden"
          this.itemCount = 0
          this.search.style.background = "#ff0000"
          this.search.style.color = "#ffffff"
        }.bind(this)
      })
    }
  },
  
  frameHandler : function() {
    var currentRequest = this.requestedImage
    var newRequest = (currentRequest != null && currentRequest != this.image)
    if (!this.fading && newRequest) {
      this.image = currentRequest
      this.initFade()
    } else if (this.fading) {
      this.continueFade()
    }
    var sv = this.search.value
    if (sv.strip() != this.previousSearchValue) {
      this.previousSearchValue = sv.strip()
      if (this.liveSearchTimeout) clearTimeout(this.liveSearchTimeout)
      this.liveSearchTimeout = setTimeout(this.bind( 'submitLiveImageSearch'), 300)
    }
  },
  
  request : function(imageName, imageIndex) {
    this.requestedImage = imageName
    var reqImg = imageName.split("/").last()
    this.nameElement.innerHTML = reqImg
    this.nameElement.href = imageName
    this.indexElement.innerHTML = (imageIndex+1) + "/" + this.itemCount
    this.searchIndexElement.innerHTML = "&nbsp;"
    this.addHistory([imageName, imageIndex])
    return true
  },
  
  searchKeyHandler : function(e) {
    if ((e.charCode | e.keyCode) == 13) {
      var sv = this.search.value
      if (this.previousSearchValue != sv || e.shiftKey) {
        if (this.liveSearchTimeout) clearTimeout(this.liveSearchTimeout)
        this.previousSearchValue = sv
        this.submitImageSearch(!e.shiftKey)
      }
      this.search.blur()
      Event.stop(e)
    } else if ((e.charCode | e.keyCode) == 27) {
      this.search.blur()
      Event.stop(e)
    }
  },

  imageSearch : function(re, goToMatch) {
    this.setQuery({ q: re }, goToMatch)
  },
  
  submitImageSearch : function(goToMatch) {
    var sv = this.previousSearchValue
    this.imageSearch(sv, goToMatch)
  },
  
  submitLiveImageSearch : function() {
    this.submitImageSearch(true)
  },
  
  initFade : function() {
    this.fadeStartTime = null
    this.fading = true
    this.loadingIndicator.style.visibility = "inherit"
    this.hiddenImage.loadImage(this.image)
  },
  
  continueFade : function() {
    if (this.hiddenImage.loaded) { // go ahead with the fade
      if (!this.fadeStartTime) {
        this.fadeStartTime = new Date().getTime()
        this.loadingIndicator.style.visibility = "hidden"
        if (this.documentFade) {
          this.visibleImage.setOpacity(1)
          this.visibleImage.up()
          this.visibleImage.show()
          this.hiddenImage.setOpacity(1)
          this.hiddenImage.down()
          this.hiddenImage.show()
        } else {
          this.hiddenImage.setOpacity(0)
          this.hiddenImage.show()
          this.hiddenImage.down()
          this.visibleImage.setOpacity(1)
          this.visibleImage.show()
          this.visibleImage.up()
        }
      }
      var currentTime = new Date().getTime()
      var elapsed = currentTime - this.fadeStartTime
      if (elapsed < this.fadeDuration) {
        var opacity = elapsed / this.fadeDuration
        if (!this.documentFade)
          this.hiddenImage.setOpacity(this.ease(opacity))
        this.visibleImage.setOpacity(this.ease(1 - opacity))
      } else { // done fading
        this.hiddenImage.setOpacity(1)
        this.visibleImage.setOpacity(0)
        this.hiddenImage.show()
        this.hiddenImage.up()
        this.visibleImage.hide()
        this.visibleImage.down()
        var tmp = this.hiddenImage
        this.hiddenImage = this.visibleImage
        this.visibleImage = tmp
        this.fading = false
      }
    }
  },
  
  focus : function(e) {
    this.display.style.borderColor = "#383838"
    this.focused = true
  },
  
  blur : function(e) {
    this.display.style.borderColor = "black"
    this.focused = false
  },

  fitDisplayToWindow : function(fitImagesToo) {
    this.root.style.width = 0
    this.root.style.height = 0
    this.display.style.width = 0
    this.display.style.height = 0
    if (this.fillWindow) {
      this.container.style.width = '100%'
      this.container.style.height = '100%'
    }
    if (fitImagesToo) {
      this.visibleImage.fitParent()
      this.hiddenImage.fitParent()
    }
    var rcs = $(this.root).getComputedStyle()
    var wm = parseInt(rcs.marginLeft) + parseInt(rcs.marginRight)
    var hm = parseInt(rcs.marginTop) + parseInt(rcs.marginBottom)
    this.root.style.width = this.container.clientWidth - wm + 'px'
    this.root.style.height = this.container.clientHeight - hm + 'px'
    this.display.style.width = this.root.clientWidth - 24 + 'px'
    this.display.style.height = this.root.clientHeight - 52 + 'px'
    if (fitImagesToo) {
      this.visibleImage.fitParent()
      this.hiddenImage.fitParent()
    }
  },

  resize : function() {
    this.fitDisplayToWindow(true)
  },
  
  clickHandler : function(e){
    if (e.button == 0 || e.button == 1) {
      var fac = this.computeClickFactor(e)
      this.rotate(fac)
      if (e.preventDefault) e.preventDefault()
      return false
    }
  },

  mousemoveHandler : function(e){
    var fac = this.computeClickFactor(e)
    if (fac != this._lastFac) {
      this._lastFac = fac
      var div = Math.pow(2, 3-(Math.abs(fac).toString().length-1))
      if (fac > 0) {
/*        var x = parseInt(393 / div)
        var y = parseInt(107 / div)
        this.display.style.cursor = 'url(GO_RIGHT_'+Math.abs(fac)+'.png) '+x+' '+y+', e-resize'*/
        this.display.style.cursor = 'e-resize'
      } else {
/*        var x = parseInt(11 / div)
        var y = parseInt(107 / div)
        this.display.style.cursor = 'url(GO_LEFT_'+Math.abs(fac)+'.png) '+x+' '+y+', w-resize'*/
        this.display.style.cursor = 'w-resize'
      }
    }
  },

  computeClickFactor : function(e){
    var fac = 1
    var hw = e.target.clientWidth / 2
    var cx = e.layerX
    fac *= (cx < hw ? -1 : 1)
    fac *= (e.shiftKey ? 10 : 1)
/*    if (Math.abs(hw - cx) > 0.4*hw) fac *= 10 
    if (Math.abs(hw - cx) > 0.8*hw) fac *= 10 */
    return fac
  },

  
  addHistory : function(v) {
    var state = {
      value: v, 
      prevByAddTime: this.prevByAddTime, 
      nextByAddTime: this.nextByAddTime, 
      prevByUndo: this.prevByUndo, 
      nextByUndo: this.nextByUndo 
    }
    this.prevByAddTime = state
    this.nextByAddTime = null
    this.prevByUndo = state
    this.nextByUndo = null
    this.history.push(state)
  },
  
  clearHistory : function() {
    this.history = []
  },
  
  prevIndex : function() {
    var prev = this.history[this.history.length-1].prevByUndo
    if (!prev) return false
    this.prevByUndo = prev.prevByUndo
    this.nextByUndo = this.history[this.history.length-1]
    this.prevByAddTime = prev.prevByAddTime
    this.nextByAddTime = prev.nextByAddTime
    return prev.value
  },
  
  nextIndex : function() {
    var next = this.history[this.history.length-1].nextByUndo
    if (!next) return false
    this.prevByUndo = next.prevByUndo
    this.nextByUndo = next.nextByUndo
    this.prevByAddTime = next.prevByAddTime
    this.nextByAddTime = next.nextByAddTime
    return next.value
  },
  
  currentIndex : function() {
    return this.history[this.history.length - 1].value
  },
  
  randomIndex : function() {
    var i = Math.floor(Math.random()*this.itemCount)
    if (i == this.itemCount) i--
    return i
  },

  goToRandom : function() {
    this.showIndex(this.randomIndex())
  },
  
  startAutoProgress : function(e) {
    this.stopAutoProgress()
    this.autoProgressElement.innerHTML = "Stop"
    if (this.window)
      this.window.parameters.autoProgress = true
    var t = this
    t.progress()
    this.autoProgressTimer = setInterval(function(){ t.progress() }, 100)
  },
  
  stopAutoProgress : function() {
    clearInterval(this.autoProgressTimer)
    if (this.window)
      this.window.parameters.autoProgress = false
    this.autoProgressTimer = null
    this.autoProgressElement.innerHTML = "Start"
  },
  
  progress : function() {
    if (this.fading) return
    if (!this._lastImageChangeTime)
      this._lastImageChangeTime = new Date().getTime()
    if (this._elapsedSinceImageChange >= this.autoProgressDelay * 1000) {
      this._elapsedSinceImageChange = 0
      this._lastImageChangeTime = false
      if (this.randomProgress) {
        this.goToRandom()
      } else {
        this.seek(this.reverseProgress ? -1 : 1)
      }
    } else {
      this._elapsedSinceImageChange = (new Date().getTime() - this._lastImageChangeTime)
    }
  },
  
  setRandomProgress : function(rp) {
    this.randomProgress = rp
    if (this.window)
      this.window.parameters.randomProgress = rp
    this.slideReverseElement.innerHTML = (this.randomProgress ? "&harr;" :
      (this.reverseProgress ? "&larr;" : "&rarr;")
    )
  },
  
  setReverseProgress : function(rp) {
    this.reverseProgress = rp
    if (this.window)
      this.window.parameters.reverseProgress = rp
    this.slideReverseElement.innerHTML = (this.reverseProgress ? "&larr;" : "&rarr;")
  },

  setAutoProgressDelay : function(seconds) {
    this.autoProgressDelay = Math.max(0,seconds) 
    if (this.window)
      this.window.parameters.autoProgressDelay = this.autoProgressDelay
    this.slideDelayElement.innerHTML = this.autoProgressDelay
    if (this.autoProgressTimer)
      this.startAutoProgress()
  },
  
  toggleRandom : function(e) {
    this.setRandomProgress(!this.randomProgress)
    Event.stop(e)
  },

  toggleReverse : function(e) {
    this.setReverseProgress(!this.reverseProgress)
    Event.stop(e)
  },
  
  toggleDirection : function(e) {
    if (this.randomProgress) {
      this.setRandomProgress(false)
      this.setReverseProgress(false)
    } else if (!this.reverseProgress) {
      this.setReverseProgress(true)
    } else {
      this.setRandomProgress(true)
    }
    Event.stop(e)
  },
  
  toggleAutoProgress : function(e) {
    (!this.autoProgressTimer ? this.startAutoProgress() : this.stopAutoProgress())
    if (e && e.preventDefault) e.preventDefault()
    return false
  },
  
  rotateAutoProgressDelay : function(offset) {
    this.setAutoProgressDelay(this.autoProgressDelay + offset) 
  },

  autoProgressDelayClickHandler : function(e) {
    this.rotateAutoProgressDelay(e.shiftKey ? -1 : 1)
    if (e.preventDefault) e.preventDefault()
    return false
  },

  keyHandler : function(e){
    if (!this.focused || this.search.focused) return
    if (e.ctrlKey || e.metaKey || e.altKey) return
    var offset, nindex
    switch(e.keyCode | e.charCode){
      case 27:
        this.search.value = ""
        this.showIndex(0)
        break
      case 33:
      case 63276:
        offset = -10
        break
      case 8:
      case 63234:
      case 63232:
      case 37:
      case 38:
        offset = -1
        break
      case 34:
      case 63277:
        offset = 10
        break
      case 32:
      case 63235:
      case 63233:
      case 39:
      case 40:
        offset = 1
        break
      case 82:
      case 114:
        nindex = this.randomIndex()
        break
      case 70:
      case 102:
        this.search.focus()
        nindex = false
        break
      case 72:
      case 104:
        this.toggleHelp()
        break
      case 83:
      case 115:
        this.toggleAutoProgress()
        break
      case 68:
      case 100:
        this.toggleReverse()
        break
      case 86:
      case 118:
        this.toggleRandom()
        break
    }
    if (e.charCode >= 48 && e.charCode <= 57) {
      this.setAutoProgressDelay(e.charCode - 48)
    }
    if (offset || (nindex != false)) {
      if (offset && e.shiftKey) offset *= 10
      if (offset) {
        this.seek(offset)
      } else {
        this.showIndex(nindex)
      }
      Event.stop(e)
    } else if (nindex === false) {
      Event.stop(e)
    }
  },
  
  toggleHelp : function(e) {
    if (this.help.style.display == 'block') {
      this.fadeOutHelp()
    } else {
      this.fadeInHelp()
    }
    Event.stop(e)
  },
  
  ease : function(val) {
    val = Math.max(0.0, Math.min(1.0, val))
    return 0.5*(-Math.cos(val * Math.PI)+1.0)
  },
  
  setHelpOpacity : function(o) {
    this.help.style.opacity = this.help.style.MozOpacity = o
    this.help.style.filters = "alpha(opacity=" + (o*100) +")"
  },
  
  fadeInHelp : function() {
    clearInterval(this.helpFader)
    this.help.style.overflow = 'auto'
    this.help.style.maxHeight = parseInt(this.display.style.height) - 10 + 'px'
    this.help.style.top = 40 + 'px'
    this.help.style.display = 'block'
    var t = this
    var st = new Date().getTime()
    var opa = parseFloat(t.help.style.opacity)
    var fader = function(){ 
      var ct = new Date().getTime()
      var dt = ct - st
      st = ct
      if (opa > 1) {
        t.help.style.top = 20 + 'px'
        t.setHelpOpacity(1)
        clearInterval(t.helpFader)
      } else {
        opa += dt*0.002
        var o = t.ease(opa)
        t.help.style.top = parseInt(Math.max(20, 40-(20 * o))) + 'px'
        t.setHelpOpacity(o)
      }
    }
    this.helpFader = setInterval(fader, this.frameTime)
  },
  
  fadeOutHelp : function() {
    clearInterval(this.helpFader)
    var t = this
    var st = new Date().getTime()
    var opa = parseFloat(t.help.style.opacity)
    var fader = function(){ 
      var ct = new Date().getTime()
      var dt = ct - st
      st = ct
      if (opa < 0) {
        t.help.style.top = 0
        t.setHelpOpacity(0)
        clearInterval(t.helpFader)
        t.help.style.display = 'none'
      } else {
        var o = t.ease(opa)
        opa -= dt*0.002
        t.help.style.top = parseInt(20 * o)
        t.setHelpOpacity(o)
      }
    }
    this.helpFader = setInterval(fader, this.frameTime)
  },

  template:
      '<form id="slideshow-bugreport-form" method="POST" style="padding:0;">' +
      '      <textarea name="bug" style="height:22px;width:400px;" '+
      '      onfocus="this.parentNode.style.opacity=1.0; window.slideshow.search.focused=true; this.rows=4; this.style.height=122; this.parentNode.style.zIndex=1000"'+
      '      onblur="this.parentNode.style.opacity=0.2; window.slideshow.search.focused=false; this.rows=1; this.style.marginTop=null; this.style.height=22; this.parentNode.style.zIndex=null;"'+
      '      ></textarea>'+
      '      <input name="submit" type="submit" value="Report Bug"'+
      '      onfocus="this.parentNode.style.opacity=1.0; window.slideshow.search.focused=true;"'+
      '      onblur="window.slideshow.search.focused=false; this.parentNode.style.opacity=0.2;"'+
      '      ></input>'+
      '</form>'+
      '<div id="slideshow-display">'+
      '  <div id="slideshow-loading">'+
      '    <div id="slideshow-loading-indicator"></div>'+
      '  </div>'+
      '  <div id="slideshow-image-1">'+
      '    <img src="suture.png" />'+
      '  </div>'+
      '  <div id="slideshow-image-2">'+
      '    <img src="suture.png" />'+
      '  </div>'+
      '</div>'+
      '<div id="slideshow-controls">'+
      '  <div id="slideshow-help">'+
      '    <div id="slideshow-help-background"></div>'+
      '     <h2>HELP</h2>'+
      '     <div id="slideshow-help-ui">'+
      '       <h3>User interface</h3>'+
      '       <h4>Slide navigation</h4>'+
      '        <p>'+
      '         <table><tr>'+
      '         <td><b>+1:</b></td><td > click on right side | right | down</td></tr><tr>'+
      '         <td><b>-1:</b></td><td > click on left side | left | up </td></tr><tr>'+
      '         <td><b>+10:</b></td><td > pgdn </td></tr><tr>'+
      '         <td><b>-10:</b></td><td > pgup </td></tr><tr>'+
      '         <td><b>Random:</b></td><td > R</td></tr>'+
      '         <td><b>10x move:</b></td><td > shift + key </td></tr><tr>'+
      '         </table>'+
      '        </p>'+
      '       <h4>History</h4>'+
      '        <p>'+
      '         <table><tr>'+
      '         <td><b>Forward:</b></td><td  width="*"> N</td></tr><tr>'+
      '         <td><b>Back:</b></td><td > B</td></tr><tr>'+
      '         </table>'+
      '        </p>'+
      '       <h4>Search</h4>'+
      '        <p>'+
      '         <table><tr>'+
      '         <td><b>Focus find field:</b></td><td> F</td></tr><tr>'+
      '         <td><b>Next result:</b></td><td> space</td></tr><tr>'+
      '         <td><b>Previous result:</b></td><td> backspace</td></tr>'+
      '         </table>'+
      '        </p>'+
      '       <h4>Slideshow</h4>'+
      '        <p>'+
      '         <table><tr>'+
      '         <td><b>Toggle slideshow:</b></td><td> S</td></tr><tr>'+
      '         <td><b>Change direction:</b></td><td> D</td></tr><tr>'+
      '         <td><b>Toggle random:</b></td><td> V</td></tr><tr>'+
      '         <td><b>Set delay:</b></td><td> number keys</td></tr><tr>'+
      '         </table>'+
      '        </p>'+
      '       <h4>Search tips</h4>'+
      '        <p>'+
      '           Shift+enter crops image list to search result.'+
      '           Esc and enter get you out of the search box.'+
      '           Esc outside the search box resets the search.'+
      '        </p>'+
      '     </div>'+
      '  </div>'+
      '  <div id="slideshow-stats">'+
      '    <div id="slideshow-index"></div>'+
      '    <div id="slideshow-stat">'+
      '      <a id="slide-name"></a>'+
      '    </div>'+
      '  </div>'+
      '  <div id="slideshow-controls-for-realz">'+
      '   <div id="slideshow-search">'+
      '    <form id="slideshow-search-form" method="GET">'+
      '      <input name="q" type="text"></input>'+
      '      <input type="submit" value="Find"></input>'+
      '    </form>'+
      '   </div>'+
      '   <div id="slideshow-autoprogress">'+
      '    <div id="slideshow-play"></div>'+
      '    <div id="slideshow-play-reverse"></div>'+
      '    <div id="slideshow-slidedelay-container">'+
      '      <div id="slideshow-slidedelay-minus"></div>'+
      '      <div id="slideshow-slidedelay"></div>'+
      '      <div id="slideshow-slidedelay-plus"></div>'+
      '    </div>'+
      '   </div>'+
      '   <div id="slideshow-help-toggle">'+
      '    <a id="slideshow-help-toggle-link" href="slideshow_help.html" target="_new">HELP</a>'+
      '   </div>'+
      '   <div id="slideshow-navigation">'+
      '    <div id="slideshow-prev-100"></div>'+
      '    <div id="slideshow-prev-10"></div>'+
      '    <div id="slideshow-prev"></div>'+
      '    <div id="slideshow-random"></div>'+
      '    <div id="slideshow-next"></div>'+
      '    <div id="slideshow-next-10"></div>'+
      '    <div id="slideshow-next-100"></div>'+
      '   </div>'+
      '  </div>'+
      '  <div id="slideshow-thumbnails">'+
      '    <div class="slideshow-thumbnail" id="slideshow-thumbnail"></div>'+
      '  </div>'+
      '</div>'
}



FaderDiv = function(div) {
  this.div = div
  this.img = div.getElementsByTagName("img")[0]
  if (navigator.userAgent.match(/rv:1\.[78].*Gecko/)) {
    var ic = E('canvas')
    if (ic.getContext) {
      this.canvas = ic
      this.canvas.style.display = 'block'
      this.canvas.style.zIndex = 1
      this.canvas.style.position = 'absolute'
      this.canvas.style.borderLeft = '1px solid #161616'
      this.canvas.style.borderTop = '1px solid #1A1A1A'
      this.canvas.style.borderRight = '1px solid #161616'
      this.canvas.style.borderBottom = '0px'
      this.scratchCanvasA = E('canvas')
      this.scratchCanvasB = E('canvas')
    }
  }
  this.shadow = document.createElement("div")
  this.shadow.style.height = "10px"
  this.shadow.style.width = "0px"
  this.shadow.style.background = "url(shadow.png) top right repeat-x"
  this.shadow.style.position = "absolute"
  this.div.appendChild(this.shadow)
}


FaderDiv.prototype = {
  loaded : false,
  
  fitParent : function() {
    var f = this.img
    var w,h,dw,dh,fw,fh
    var d = f.parentNode
    dw = d.offsetWidth
    dh = d.offsetHeight
    f.style.width = null
    f.style.height = null
    fw = f.width
    fh = f.height
    if (fw <= dw && fh <= dh) {
      w = fw
      h = fh
    } else if (fw > fh) {
      w = dw
      h = fh * (dw / fw)
    } else {
      w = fw * (dh / fh)
      h = dh
    }
    if (w > dw) {
      w = dw
      h = fh * (dw / fw)
    } else if (h > dh) {
      w = fw * (dh / fh)
      h = dh
    }
    if ((fw > w || fh > h) && fw*fh < 3000*4000) { // don't canvas-scale huge images
      this.setElementOpacity(f, 0)
      f.style.zIndex = 2
      f.parentNode.insertAfter(this.canvas, f)
      this.canvas.style.top = Math.ceil((dh - h) / 2) + 'px'
      this.canvas.style.left = Math.ceil((dw - w) / 2) + 'px'
      this.canvas.width = Math.ceil(w)
      this.canvas.height = Math.ceil(h)
      if (w > 0 && w < fw / 2) {
      // hacky multi-level downscaling that produces marginally better results
      // than a single bi-linear downscale (but still craps out with 1px glows
      // surrounding linework (i.e. high amplitude&freq line: -^_-))
        var a = this.scratchCanvasA
        var b = this.scratchCanvasB
        var tmp
        var sw = fw * 0.6
        var sh = fh * 0.6
        a.width = Math.ceil(sw)
        a.height = Math.ceil(sh)
        var ac = a.getContext('2d')
        var bc = b.getContext('2d')
        ac.clearRect(0,0,a.width,a.height)
        ac.drawImage(f,0,0,sw,sh)
        while (w < sw * 0.5) {
          sw *= 0.6
          sh *= 0.6
          b.width = Math.ceil(sw)
          b.height = Math.ceil(sh)
          bc.clearRect(0,0,b.width,b.height)
          bc.drawImage(a,0,0,sw,sh)
          tmp = a
          a = b
          b = tmp
          tmp = ac
          ac = bc
          bc = tmp
        }
        var c = this.canvas.getContext('2d')
        c.drawImage(a,0,0,Math.ceil(w),Math.ceil(h))
        a.width = a.height = b.width = b.height = 0
      } else {
        var c = this.canvas.getContext('2d')
        c.drawImage(f,0,0,Math.ceil(w),Math.ceil(h))
      }
      this.setElementOpacity(this.canvas, this.opacity)
    } else if (this.canvas.parentNode) {
      $(this.canvas).detachSelf()
      this.setElementOpacity(f, this.opacity)
    }
    f.style.top = Math.ceil((dh - h) / 2) + 'px'
    f.style.left = Math.ceil((dw - w) / 2) + 'px'
    f.style.width = Math.ceil(w) + 'px'
    f.style.height = Math.ceil(h) + 'px'
    this.shadow.style.top = Math.ceil(h) + parseInt(f.style.top) + 'px'
    this.shadow.style.left = parseInt(f.style.left) + 'px'
    this.shadow.style.width = Math.ceil(w) + 2  + 'px'
  },
  
  up: function() {
    this.div.style.zIndex = 2
  },
  
  down: function() {
    this.div.style.zIndex = 1
  },
  
  hide : function() {
    this.div.style.visibility = "hidden"
  },
  
  show : function() {
    this.div.style.visibility = "inherit"
  },
  
  setOpacity : function(op) {
    this.opacity = op
    if (this.canvas.parentNode)
      this.setElementOpacity(this.canvas, op)
    else
      this.setElementOpacity(this.img, op)
    this.setElementOpacity(this.shadow, Math.max(op, 0))
  },
  
  setElementOpacity : function(o, op) {
    o.style.opacity = op
    o.style.MozOpacity = op
    o.style.filters = "alpha(opacity=" + (op * 100) + ")"
  },
  
  loadImage : function(name) {
    this.loaded = false
    this.div.removeChild(this.img)
    this.div.removeChild(this.shadow)
    this.img = document.createElement('img')
    this.img.addEventListener("load", this.loadHandler.bind(this), false)
    this.img.setAttribute('src', name)
    this.img.style.display = 'none'
    this.img.style.borderLeft = '1px solid #161616' 
    this.img.style.borderTop = '1px solid #1A1A1A' 
    this.img.style.borderRight = '1px solid #161616' 
    this.img.style.borderBottom = '0px' 
    this.div.appendChild(this.img)
    this.div.appendChild(this.shadow)
  },
  
  loadHandler : function(e) {
    this.fitParent()
    this.img.style.display = 'inherit'
    this.loaded = true
    if (e.preventDefault) e.preventDefault()
    return false
  }
}

