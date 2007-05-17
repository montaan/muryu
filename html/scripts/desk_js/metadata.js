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
      try { ax.transport.send('') } catch(e) {}
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
    image : ['jpg', 'png', 'gif'],
    html : ['html', 'org', 'com', 'net'],
    playlist : ['m3u']
  }),
  
  guess : function(src) {
    if (src[src.length-1] == '/')
      var ext = 'html'
    else
      var ext = src.split('.').last()
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


