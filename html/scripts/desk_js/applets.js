Applets = {
  bakeAppletMenu: function(applet) {
    applet.menu.addTitle('Applet')
    applet.menu.addItem('Remove Applet', function(){
      applet.panel.removeApplet(applet)
    }, 'icons/Remove.png')
    applet.addEventListener('click', function(e){
      if (Event.isLeftClick(e) && e.ctrlKey) {
        applet.menu.show(e)
        Event.stop(e)
      }
    },false)
  }
}


Applets.Session = function(wm) {
  if (!wm) wm = Desk.Windows
  var c = E('span', null, null, 'taskbarApplet Session')
  var title = E('h4', 'Session', null, 'windowGroupTitle')
  c.appendChild(title)
  c.session = null
  c.autosave = true
  c.toggleAutosave = function(){
    this.setAutosave(!this.autosave)
  }
  c.setAutosave = function(d){
    this.autosave = d
    if (this.autosave) {
      this.menu.checkItem('Autosave')
    } else {
      this.menu.uncheckItem('Autosave')
    }
  }
  c.autosaveSession = function(){
    if (this.autosave)
      this.saveSession()
  }
  c.saveSession = function(){
      Session.save()
  }
  c.clearSession = function(){
    Session.clear()
  }
  c.dumpSession = function(){
    return {loader: 'Applets.Session', data: ''}
  }

  wm.addListener('addWindow', function(e){
    if (e.value.avoid) {
      e.addListener('addApplet', c.autosaveSession)
      e.addListener('removeApplet', c.autosaveSession)
    }
    c.autosaveSession()
  })
  wm.addListener('removeWindow', function(e){
    if (e.value.avoid) {
      e.removeListener('addApplet', c.autosaveSession)
      e.removeListener('removeApplet', c.autosaveSession)
    }
    c.autosaveSession()
  })
  window.addEventListener('unload', c.saveSession, false)
  c.menu = new Desk.Menu()
  c.menu.addTitle('Session')
  c.menu.addItem('Save session now', c.saveSession)
  c.menu.addItem('Autosave', function(){
    c.toggleAutosave()
  })
  c.menu.checkItem('Autosave')
  c.menu.addSeparator()
  c.menu.addItem('Clear session', c.clearSession)
  Applets.bakeAppletMenu(c)

  return c
}
Applets.Session.loadSession = function(dump) {
  return Applets.Session()
}


Applets.OpenURL = function(wm) {
  if (!wm) wm = Desk.Windows
  var c = E('span', null,null, 'taskbarApplet OpenURL')
  c.dumpSession = function(){
    return {loader: 'Applets.OpenURL', data: ''}
  }
  var f = E('form', null,null, 'taskbarForm')
  var title = E('h4', 'Open URL', null, 'windowGroupTitle')
//   Draggable.makeDraggable(title)
  var t = E('input',null,null,'taskbarTextInput',null,
    {type:'text'})
  var s = E('input',null,null,'taskbarSubmitInput',null,
    {type:'submit', value:'Open'})
  c.appendChild(title)
  c.appendChild(f)
  f.appendChild(t)
  f.appendChild(s)
  c.openURL = function(new_src) {
    if (new_src.length > 0) {
      if (new_src[0] == '/')
        new_src = 'file://' + new_src
      if (!new_src.match(/^(\.|[a-z]+:)/i))
        new_src = 'http://' + new_src
      var mt = Mime.guess(new_src).mimetype
      var w = new Desk.Window(new_src, {
        group: mt.capitalize(),
        minimized: (soundManager && soundManager.enabled && mt == 'music')
      })
    }
  }
  t.addEventListener('focus', function(e){
    this.select()
  }, false)
  f.addEventListener('submit', function(e){
    var new_src = t.value.toString()
    f.blur()
    Event.stop(e)
    c.openURL(new_src)
  }, false)
  c.menu = new Desk.Menu()
  Applets.bakeAppletMenu(c)
  return c
}
Applets.OpenURL.loadSession = function(dump) {
  return Applets.OpenURL()
}


Applets.MusicPlayer = function() {
  var c = E('span', null,null, 'taskbarApplet MusicPlayer')
  var title = E('h4', 'Music player', null, 'windowGroupTitle')
  c.addWindowHandler = function(e){
    if (e.window.src && e.window.src.split(".").last().match(/mp3|m3u/i)) {
      this.playlist.push(e.window)
    }
  }.bind(c)
  c.removeWindowHandler = function(e){
    c.playlist.deleteFirst(e.window)
  }.bind(c)
  Desk.Windows.addListener('add', c.addWindowHandler)
  Desk.Windows.addListener('remove', c.removeWindowHandler)
  c.addEventListener('DOMNodeRemoved', function(){
    if (e.target == c) {
      Desk.Windows.removeListener('add', c.addWindowHandler)
      Desk.Windows.removeListener('remove', c.removeWindowHandler)
    }
  }, false)
  c.appendChild(title)

  c.mergeD(EventListener)
  c.playlist = []
  c.playlistGroup = null
  c.playlistIndex = 0
  c.currentIndex = 0
  c.playlistStack = []
  c.currentURL = null
  c.repeating = true
  c.shuffling = false
  c.soundID = 'currentMPSound'
  c.firstPlay = true
  c.loadPlaylist = function(src){
    new Desk.Window(src, {
      minimized: true,
      group: 'Playlists'
    })
  }
  c.extractSrc = function(win) {
    return (c.metadata && c.metadata.urls) || c.src
  }

  c.getPlaylistLength = function(playlist, i) {
    if (this.playlistStack.isEmpty())
      var pls = [this.playlist, this.playlistIndex]
    else
      var pls = this.playlistStack[0]
    if (!playlist) playlist = pls[0]
    if (i == undefined) i = playlist.length
    return this.computePlaylistLength(playlist, i)
  }
  c.computePlaylistLength = function(playlist, i) {
    return playlist.slice(0,i).inject(0, function(s, e){
      if (this.isPlaylist(e)) {
        return s + this.computePlaylistLength(e.metadata.urls, e.metadata.urls.length)
      } else {
        return s + 1
      }
    }.bind(this))
  }
  c.collectPlaylistUpto = function(playlist, i, count) {
    if (!count) count = [[], 0]
    for (var j=0; j<playlist.length; j++) {
      var e = playlist[j]
      if (this.isPlaylist(e)) {
        count[0].push([playlist, j])
        this.collectPlaylistUpto(e.metadata.urls, i, count)
        if (count[1] > i) return count
        count[0].pop()
      } else {
        count[1] += 1
        if (count[1] > i) {
          count[0].push([playlist, j])
          return count
        }
      }
    }
    return false
  }
  c.next = function(){
    if (this.shuffling) {
      this.gotoIndex(Math.floor(Math.random()*this.getPlaylistLength()))
    } else {
      this.playlistIndex += 1
      this.currentIndex += 1
      this.play()
    }
  }
  c.previous = function(){
    this.playlistIndex -= 1
    this.currentIndex -= 1
    this.play()
  }
  c.gotoFirst = function(startPlaying){
    this.gotoIndex(0, startPlaying)
  }
  c.gotoIndex = function(index, startPlaying){
    if (startPlaying == undefined) startPlaying = true
    var pl = (this.playlistStack.isEmpty()) ?
             this.playlist : this.playlistStack[0][0]
    var stack = c.collectPlaylistUpto(pl, index)
    if (stack) {
      var top = stack[0].pop()
      this.playlistStack = stack[0]
      this.playlist = top[0]
      this.playlistIndex = top[1]
      this.currentIndex = index
      if (startPlaying) this.play()
    }
  }
  c.playNext = function() {
    if (this.repeating)
      this.play()
    else
      this.next()
  }.bind(c)
  c.isPlaylist = function(w) {
    return (w && w.metadata && w.metadata.urls)
  }
  c.shuffle = function(){
    this.setShuffling(!this.shuffling)
  }
  c.setShuffling = function(v) {
    if (v != this.shuffling)
      this.shuffleButton.toggle()
    this.shuffling = v
    if (this.shuffling) this.menu.checkItem('Shuffle')
    else this.menu.uncheckItem('Shuffle')
  }
  c.repeat = function(){
    this.setRepeating(!this.repeating)
  }
  c.setRepeating = function(v) {
    if (v != this.repeating)
      this.repeatButton.toggle()
    this.repeating = v
    if (this.repeating) this.menu.checkItem('Repeat Song')
    else this.menu.uncheckItem('Repeat Song')
  }
  c.play = function(){
    if (!this.playlist.isEmpty()) {
      if (this.firstPlay) {
        this.firstPlay = false
        this.gotoIndex(this.currentIndex, false)
      }
      this.playButton.style.display = 'none'
      this.pauseButton.style.display = null
      this.playing = true
      while (this.playlistIndex >= this.playlist.length) {
        if (this.playlistStack.isEmpty()) {
          this.playlistIndex = 0
          this.currentIndex = 0
        } else {
          var pi = this.playlistStack.pop()
          this.playlist = pi[0]
          this.playlistIndex = pi[1] + 1
        }
      }
      var gotoEnd = false
      while (this.playlistIndex < 0) {
        if (this.playlistStack.isEmpty()) {
          this.playlistIndex = Math.max(
            this.playlist.length-1, 0)
          this.currentIndex = this.getPlaylistLength() - 1
        } else {
          var pi = this.playlistStack.pop()
          this.playlist = pi[0]
          this.playlistIndex = pi[1] - 1
        }
        gotoEnd = true // start at the end of the playlist
      }
      this.currentItem = this.playlist[this.playlistIndex]
      while (this.isPlaylist(this.currentItem)) {
        this.playlistStack.push(
          [this.playlist, this.playlistIndex])
        this.playlist = this.currentItem.metadata.urls
        this.playlistIndex = (gotoEnd ?
          Math.max(this.playlist.length-1, 0) : 0)
        this.currentItem = this.playlist[this.playlistIndex]
      }
      if (this.currentItem) {
        this.currentURL = (typeof this.currentItem == 'string' ?
                          this.currentItem :
                          this.currentItem.src)
        soundManager.load(this.soundID,
          {url: this.currentURL, autoPlay: true})
        this.paused = false
      } else {
        setTimeout(this.playNext, 0)
      }
    } else {
      this.paused = true
      this.currentIndex = 0
      this.newEvent('songChanged', {value: ''})
    }
    this.updateButtons()
  }

  c.pause = function(){
    if (this.playing) {
      if (this.paused)
        soundManager.resume(this.soundID)
      else
        soundManager.pause(this.soundID)
      this.paused = !this.paused
      this.updateButtons()
    } else {
      this.play()
    }
  }
  c.stop = function() {
    if (this.playing) {
      soundManager.stop(this.soundID)
      this.playing = false
    }
    this.paused = false
    this.updateButtons()
  }
  c.updateButtons = function() {
    if (this.paused) {
      this.pauseButton.style.display = 'none'
      this.playButton.style.display = null
    } else {
      this.playButton.style.display = 'none'
      this.pauseButton.style.display = null
    }
  }
  soundManager.onload = function() {
    soundManager.createSound(c.soundID, {url: 'data/null.mp3'})
    c.sound = soundManager.sounds[c.soundID]
    c.sound.options.onfinish = c.playNext
    c.sound.options.onid3 = function(e){
      var elems = [c.sound.id3.artist, c.sound.id3.songname]
      c.newEvent('songChanged', {value: elems.join(" - ")})
    }
  }

  c.playButton = Desk.Button('Play', c.pause.bind(c))
  c.pauseButton = Desk.Button('Pause', c.pause.bind(c))
  c.pauseButton.style.display = 'none'
  c.prevButton = Desk.Button('Previous', c.previous.bind(c))
  c.nextButton = Desk.Button('Next', c.next.bind(c))
  c.shuffleButton = Desk.Button('Shuffle', c.shuffle.bind(c))
  if (c.shuffling) c.shuffleButton.toggle()
  c.repeatButton = Desk.Button('Repeat', c.repeat.bind(c))
  if (c.repeating) c.repeatButton.toggle()
  c.appendChild(c.prevButton)
  c.appendChild(c.pauseButton)
  c.appendChild(c.playButton)
  c.appendChild(c.nextButton)
  c.appendChild(c.shuffleButton)
  c.appendChild(c.repeatButton)

  c.indexElem = E('span', null, null, 'CurrentIndex')
  c.appendChild(c.indexElem)
  c.sepElem = E('span', null, null, 'IndexSeparator')
  c.appendChild(c.sepElem)
  c.allElem = E('span', null, null, 'PlaylistLength')
  c.appendChild(c.allElem)
  c.currentlyPlaying = E('span', null, null, 'CurrentlyPlaying')
  c.appendChild(c.currentlyPlaying)
  c.addListener('songChanged', function(e){
    c.indexElem.innerHTML = (c.currentIndex+1)
    c.allElem.innerHTML = c.getPlaylistLength()
    c.currentlyPlaying.innerHTML = e.value
  })
  
  Droppable.makeDroppable(c)
  c.drop = function(dragged, e) {
    if (dragged.className.match(/\bwindowTaskbarEntry\b/)) {
      var w = dragged.window
      if (w.src && w.src.split(".").last().match(/mp3|m3u/i)) {
        this.playlistStack = []
        this.playlist = [w]
        this.playlistIndex = 0
        this.currentIndex = 0
        this.play()
      }
    } else if (dragged.className.match(/\bwindowGroupTitle\b/)) {
      this.playlistStack = []
      this.playlist = dragged.windowGroup.findAll(function(w){
        return w.src && w.src.split(".").last().match(/mp3|m3u/i)
      })
      this.playlistIndex = 0
      this.currentIndex = 0
      this.play()
    }
  }
  c.dumpSession = function(){
    return {
      loader: 'Applets.MusicPlayer',
      data: {
        currentIndex : this.currentIndex,
        repeating : this.repeating,
        shuffling : this.shuffling
      }
    }
  }
  c.menu = new Desk.Menu()
  c.menu.addTitle('Music player')
  c.menu.addItem('Play', c.play.bind(c))
  c.menu.addItem('Pause', c.pause.bind(c))
  c.menu.addItem('Stop', c.stop.bind(c))
  c.menu.addItem('Previous', c.previous.bind(c))
  c.menu.addItem('Next', c.next.bind(c))
  c.menu.addSeparator()
  c.menu.addItem('Repeat Song', c.repeat.bind(c))
  if (c.repeating) c.menu.checkItem('Repeat Song')
  else c.menu.uncheckItem('Repeat Song')
  c.menu.addItem('Shuffle', c.shuffle.bind(c))
  if (c.shuffling) c.menu.checkItem('Shuffle')
  else c.menu.uncheckItem('Shuffle')
  c.menu.addSeparator()
  c.menu.addItem('Clear playlist')
  Applets.bakeAppletMenu(c)

  return c
}
Applets.MusicPlayer.loadSession = function(data) {
  var mp = Applets.MusicPlayer()
  mp.currentIndex = data.currentIndex
  mp.setShuffling(data.shuffling)
  mp.setRepeating(data.repeating)
  return mp
}
