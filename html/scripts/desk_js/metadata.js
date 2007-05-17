Metadata = {
  get : function(src) {
    var metadata = {}
    var mime = Mime.guess(src)
    Object.extend(metadata, mime)
    metadata.title = src.split("/").last()
    return metadata
  }
}



Mimetype = {
  json : {
    mimetype : 'json',
    makeEmbed : function(src) {
      return E('div')
    },
    
    init : function(src, win) {
      new Ajax.Request(src, {
        method : 'get',
        onSuccess : function(res) {
          var info = res.responseText.evalJSON()
          win.setTitle(this.parseTitle(info))
          win.content.appendChild(this.createViewer(info, win))
        }.bind(this)
      })
    },

    parseTitle : function(info) {
      return (info.metadata.title || info.title || info.path.split("/").last())
    },

    createViewer : function(info,win) {
      var viewer
      try {
        if (['image/jpeg','image/png','image/gif'].include(info.mimetype))
          viewer = this.makeImageViewer(info,win)
        else if (info.mimetype.match(/\bvideo\b/))
          viewer = this.makeVideoViewer(info,win)
        else if (info.mimetype.split("/")[0] == 'audio')
          viewer = this.makeAudioViewer(info,win)
        else if (info.mimetype == 'text/html')
          viewer = this.makeHTMLViewer(info,win)
        else if (info.mimetype.split("/")[0] == 'text')
          viewer = this.makeTextViewer(info,win)
        else
          viewer = this.makeThumbViewer(info,win)
      } catch(e) {
        console.log('hälärm', e)
      }
      return viewer
    },

    makeUserInfoDiv : function(info) {
    },

    makeMetadataDiv : function(info) {
    },

    makeImageViewer : function(info,win) {
      this.easyMove = true
      var i = E('img')
      var mw = win.container.offsetWidth
      var mh = win.container.offsetHeight
      var iw = info.metadata.width
      var ih = info.metadata.height
      i.width = 0
      i.height = 0
      i.onmousedown = function(e){
        this.downX = e.clientX
        this.downY = e.clientY
      }
      i['ondblclick'] = function(e){
        if (Event.isLeftClick(e) &&
            Math.abs(this.downX - e.clientX) < 3 &&
            Math.abs(this.downY - e.clientY) < 3) win.close()
      }
      i.src = Map.__filePrefix + info.path
      win.content.appendChild(i)
      if (mw < (iw + 20)) {
        ih *= (mw - 20) / iw
        iw = mw - 20
      }
      var lh = 16 + win.element.offsetHeight
      if (mh < (ih + lh)) {
        iw *= (mh - lh) / ih
        ih = mh - lh
      }
      i.width = iw
      i.height = ih
      if (i.width < info.metadata.width || i.height < info.metadata.height) {
        if (navigator.userAgent.match(/rv:1\.[78].*Gecko/)) {
          var ic = E('canvas')
          if (ic.getContext) {
            ic.style.display = 'block'
            ic.width = iw
            ic.height = ih
            ic.onclick = i.onclick
            i.onload = function(){
              i.style.position = 'absolute'
              i.style.opacity = 0
              i.style.zIndex = 2
              ic.style.zIndex = 1
              i.parentNode.insertAfter(ic, i)
              var c = ic.getContext('2d')
              c.drawImage(i,0,0,iw,ih)
            }
          }
        }
      }
      return i
    },
    
    makeVideoViewer : function(info) {
      var i = E('embed')
      i.width = info.metadata.width
      i.height = info.metadata.height
      i.src = Map.__filePrefix + info.path
      i.setAttribute("type", "application/x-mplayer2")
      return i
    },

    makeAudioViewer : function(info) {
      var i = E('embed')
      i.width = 400
      i.height = 16
      i.src = Map.__filePrefix + info.path
      i.setAttribute("type", info.mimetype)
      return i
    },

    makeHTMLViewer : function(info) {
      var i = E('iframe')
      i.style.backgroundColor = "white"
      i.width = 600
      i.height = 400
      i.src = Map.__filePrefix + info.path
      return i
    },

    makeTextViewer : function(info) {
      var i = E('iframe')
      i.style.backgroundColor = "white"
      i.width = 600
      i.height = 400
      i.src = Map.__filePrefix + info.path
      return i
    },

    makeThumbViewer : function(info, win) {
      var i = E('img')
      i.onmousedown = function(e){
        this.downX = e.clientX
        this.downY = e.clientY
      }
      i['ondblclick'] = function(e){
        if (Event.isLeftClick(e) &&
            Math.abs(this.downX - e.clientX) < 3 &&
            Math.abs(this.downY - e.clientY) < 3) win.close()
      }
      i.src = Map.__filePrefix + info.path
      return i
    }
  },

  audio : {
    mimetype : 'audio',
    makeEmbed : function(src) {
      var e = E('embed')
      e.src = src
      e.height = '16px'
      e.setAttribute('autoplay', 'false')
      return e
    }
  },
  
  music : {
    mimetype : 'music',
    makeEmbed : function(src) {
      var e
      if (soundManager && !soundManager._disabled) {
        e = this.smMakeEmbed(src)
      } else {
        e = Mimetype['audio'].makeEmbed(src)
      }
      this.embed = e
      return e
    },
    
    smMakeEmbed : function(src) {
      return A(src, src)
    }
  },

  playlist : {
    mimetype : 'playlist',
    makeEmbed : function(src) {
      var e = A(src, src)
      this.embed = e
      return e
    },
    init : function(src) {
      this.urls = []
      var ax = new Ajax.Request(src, {
        method: 'get',
        onSuccess: function(res) {
          this.urls = res.responseText.split("\n").findAll(function(line){
            return (line.length > 0) })
        }.bind(this)
      })
    }
  },

  video : {
    mimetype : 'video',
    makeEmbed : function(src) {
      var e = E('embed')
      e.src = src
      e.setAttribute('autoplay', 'false')
      this.embed = e
      return e
    }
  },

  image : {
    easyMove : true,
    mimetype : 'image',
    makeEmbed : function(src) {
      var e = E('img')
      e.style.display = 'block'
      e.src = src
      this.embed = e
      return e
    }
  },

  html : {
    mimetype : 'html',
    makeEmbed : function(src) {
      var e = E('iframe')
      e.src = src
      e.style.width = '800px'
      e.style.height = '600px'
      this.embed = e
      return e
    },
    init : function(src, win) {
      win.addListener('resize', function(e){
        this.embed.style.width = e.target.contentElement.style.width
        this.embed.style.height = e.target.contentElement.style.height
      }.bind(this))
    }
  }
}

Mime = {
  typeExtensions : new Hash({
    video : ['avi', 'mpg', 'wmv', 'mov'],
    audio : ['wav', 'ogg'],
    music : ['mp3'],
    image : ['jpg', 'jpeg', 'png', 'gif'],
    html : ['html', 'org', 'com', 'net'],
    playlist : ['m3u'],
    json : ['json']
  }),
  
  guess : function(src) {
    if (src.split("/").last() == 'json')
      var ext = 'json'
    else if (src[src.length-1] == '/')
      var ext = 'html'
    else
      var ext = src.split('.').last().toLowerCase()
    var type = this.extensions[ext]
    var mimetype = Mimetype[type] || Mimetype['html']
    return mimetype
  }
}
Mime.extensions = new Hash()
Mime.typeExtensions.each(function(kv){
  kv[1].each(function(ext){
    Mime.extensions[ext] = kv[0]
  })
})


