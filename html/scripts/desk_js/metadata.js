Metadata = {
  get : function(src) {
    var metadata = {}
    var mime = Mime.guess(src)
    Object.extend(metadata, mime)
    metadata.title = src.split("/").last()
    return metadata
  }
}

Tr.addTranslations('en-US', {
  'Item.DateObject' : function(d){
    weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    return (weekdays[d.getDay()] + ', ' + months[d.getMonth()] + ' ' +
            d.getDate() + ', ' + (d.getYear() + 1900) + ' ' +
            (d.getHours()%13).toString().rjust(2, '0') + ':' +
            d.getMinutes().toString().rjust(2, '0') + ':' +
            d.getSeconds().toString().rjust(2, '0') + ' ' +
            (d.getHours() < 13 ? 'am' : 'pm'))
  },
  'Item.welcome' : function(name){
    return 'Welcome, '+name
  },
  'Item.sign_in' : 'Log in',
  'Item.register' : 'Create account',
  'Item.sign_out' : 'Log out',
  'Item.username' : 'Account name',
  'Item.password' : 'Password',
  'Item.by' : 'by',
  'Item.author' : 'author',
  'Item.date_taken' : 'created at',
  'Item.camera' : 'camera',
  'Item.manufacturer' : 'manufacturer',
  'Item.software' : 'software',
  'Button.Item.edit' : 'Edit metadata',
  'Button.Item.delete_item' : 'Delete',
  'Button.Item.undelete_item' : 'Undelete',
  'Item.filename' : 'filename',
  'Item.source' : 'source',
  'Item.referrer' : 'referrer',
  'Item.sets' : 'sets',
  'Item.groups' : 'groups',
  'Item.tags' : 'content',
  'Item.mimetype' : 'file type',
  'Item.deleted' : 'deleted',
  'Item.title' : 'title',
  'Item.publisher' : 'publisher',
  'Item.publish_time' : 'publish time',
  'Item.description' : 'description',
  'Item.location' : 'location',
  'Item.genre' : 'genre',
  'Item.album' : 'album',
  'Item.tracknum' : 'track number',
  'Item.album_art' : 'album art',
  'Item.cancel' : 'cancel',
  'Item.done' : 'save',
  'Item.edit_failed' : 'Saving edits failed',
  'Item.delete_failed' : 'Deleting item failed',
  'Item.loading_tile_info' : 'Loading tile info failed',
  'Item.loading_item_info' : 'Loading item info failed',
  'Item.byte_abbr' : 'B',
  'Item.click_to_edit_title' : 'Click to edit item title',
  'Item.click_to_edit_author' : 'Click to edit item author',
  'Item.item' : 'item',
  'Item.metadata' : 'metadata',
  
  'Item.Editing' : 'Editing ',
  'Item.Deleting' : 'Deleting ',
  'Item.Undeleting' : 'Undeleting ',
  'WindowGroup.editors' : 'editors',
  'WindowGroup.deletions' : 'deletions',
  'WindowGroup.undeletions' : 'undeletions',
  'WindowGroup.images' : 'images',
  'WindowGroup.music' : 'music',
  'WindowGroup.videos' : 'videos',
  'WindowGroup.text' : 'text',
  'WindowGroup.HTML' : 'HTML',
})
Tr.addTranslations('en-GB', {
  'Item.DateObject' : function(d){
    weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    return (weekdays[d.getDay()] + ', ' + d.getDate() + ' ' +
            months[d.getMonth()] + ' ' + (d.getYear() + 1900) + ' ' +
            (d.getHours()%13).toString().rjust(2, '0') + ':' +
            d.getMinutes().toString().rjust(2, '0') + ':' +
            d.getSeconds().toString().rjust(2, '0') + ' ' +
            (d.getHours() < 13 ? 'am' : 'pm'))
  }
})
Tr.addTranslations('fi-FI', {
  'Item.DateObject' : function(d){
    weekdays = ['su', 'ma', 'ti', 'ke', 'to', 'pe', 'la']
    months = ['tammi', 'helmi', 'maalis', 'huhti', 'touko', 'kesä', 'heinä', 'elo', 'syys', 'loka', 'marras', 'joulu']
    return (weekdays[d.getDay()] + ' ' + d.getDate() + '. ' +
            months[d.getMonth()] + 'kuuta ' + (d.getYear() + 1900) + ' ' +
            d.getHours().toString().rjust(2, '0') + ':' +
            d.getMinutes().toString().rjust(2, '0') + ':' +
            d.getSeconds().toString().rjust(2, '0'))
  },
  'Item.welcome' : function(name){
    return 'Tervetuloa, '+name
  },
  'Item.sign_in' : 'Kirjaudu sisään',
  'Item.register' : 'Luo tunnuksesi',
  'Item.sign_out' : 'Lopeta',
  'Item.username' : 'Tunnus',
  'Item.password' : 'Salasana',
  'Item.by' : '-',
  'Item.author' : 'tekijä',
  'Item.date_taken' : 'luotu',
  'Item.camera' : 'kamera',
  'Item.manufacturer' : 'valmistaja',
  'Item.software' : 'ohjelmisto',
  'Button.Item.edit' : 'Muokkaa tietoja',
  'Button.Item.delete_item' : 'Poista',
  'Button.Item.undelete_item' : 'Tuo takaisin',
  'Item.filename' : 'tiedostonimi',
  'Item.source' : 'lähde',
  'Item.referrer' : 'viittaaja',
  'Item.sets' : 'joukot',
  'Item.groups' : 'ryhmät',
  'Item.tags' : 'tagit',
  'Item.mimetype' : 'tiedostomuoto',
  'Item.deleted' : 'poistettu',
  'Item.title' : 'nimeke',
  'Item.publisher' : 'julkaisija',
  'Item.publish_time' : 'julkaisuaika',
  'Item.description' : 'kuvaus',
  'Item.location' : 'sijainti',
  'Item.genre' : 'tyylilaji',
  'Item.album' : 'albumi',
  'Item.tracknum' : 'raidan numero',
  'Item.album_art' : 'kansitaide',
  'Item.cancel' : 'peruuta',
  'Item.done' : 'tallenna',
  'Item.edit_failed' : 'Muutosten tallentaminen epäonnistui',
  'Item.delete_failed' : 'Poisto epäonnistui',
  'Item.loading_tile_info' : 'Tiilen tietojen lataaminen epäonnistui',
  'Item.loading_item_info' : 'Kohteen tietojen lataaminen epäonnistui',
  'Item.byte_abbr' : 't',
  'Item.click_to_edit_title' : 'Napsauta muokataksesi nimekettä',
  'Item.click_to_edit_author' : 'Napsauta muokataksesi tekijän nimeä',
  'Item.item' : 'kohde',
  'Item.metadata' : 'sisältö',
  
  'Item.Editing' : function(name) {
    return 'Muokkain ' + name + ':lle'
  },
  'Item.Deleting' : function(name) {
    return 'Poistan kohteen ' + name
  },
  'Item.Undeleting' : function(name) {
    return 'Tuon takaisin kohteen ' + name
  },
  'WindowGroup.editors' : 'muokkaimet',
  'WindowGroup.deletions' : 'poistot',
  'WindowGroup.undeletions' : 'takaisintuonnit',
  'WindowGroup.images' : 'kuvat',
  'WindowGroup.music' : 'musiikki',
  'WindowGroup.videos' : 'videot',
  'WindowGroup.text' : 'tekstit',
  'WindowGroup.HTML' : 'HTML',
})
Tr.addTranslations('de-DE', {
  'Item.by' : '-',
  'Item.author' : 'Urheber',
  'Item.date_taken' : 'Erstellungsdatum',
  'Item.camera' : 'Kameramodell',
  'Item.manufacturer' : 'Hersteller',
  'Item.software' : 'Software',
  'Button.Item.edit' : 'Metadaten bearbeiten',
  'Item.filename' : 'Dateiname',
  'Item.source' : 'Quelle',
  'Item.referrer' : 'Referrer',
  'Item.sets' : 'Garnituren',
  'Item.groups' : 'Gruppen',
  'Item.tags' : 'Tags',
  'Item.mimetype' : 'Dateityp',
  'Item.deleted' : 'gelöscht',
  'Item.title' : 'Titel',
  'Item.publisher' : 'Herausgeber',
  'Item.publish_time' : 'Veröffentlichungszeit',
  'Item.description' : 'Beschreibung',
  'Item.location' : 'Ort',
  'Item.genre' : 'Genre',
  'Item.album' : 'Album',
  'Item.tracknum' : 'Titelnummer',
  'Item.album_art' : 'Albencover',
  'Item.cancel' : 'abbrechen',
  'Item.done' : 'speichern',
  'Item.edit_failed' : 'Speicherung der Änderungen fehlgeschlagen',
  'Item.loading_tile_info' : 'Kachelladevorgang fehlgeschlagen',
  'Item.loading_item_info' : 'Dateiladevorgang fehlgeschlagen',
  'Item.byte_abbr' : 'B',
  'Item.click_to_edit_title' : 'Klicken Sie hier, um den Titel zu ändern',
  'Item.click_to_edit_author' : 'Klicken Sie hier, um den Urhebernamen zu ändern',
  'Item.item' : 'Datei',
  'Item.metadata' : 'Metadaten'
})

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
          try {
            var info = res.responseText.evalJSON()
            win.setTitle(this.parseTitle(info, win))
            win.content.appendChild(this.parseUserInfo(info, win))
            win.content.appendChild(this.createViewer(info, win))
            win.content.appendChild(this.parseItemMetadata(info, win))
          } catch(e) { console.log(e) }
        }.bind(this)
      })
    },

    parseTitle : function(info, win) {
      return this.parseItemTitle('span', info, win, true, true, '')
    },

    // Create item title from info. Show title if metadata.title exists and
    // show_title is true. Show possible dimensions and author when show_metadata
    // is true.
    //
    // Returns the title as a element named in tag.
    //
    parseItemTitle : function(tag, info, win, show_title, show_metadata, klass) {
      var elem = E(tag, null, null, klass)
      var metadata = E('span')
      if (!info.metadata)
        return info.path.split("/").last()
      if (info.metadata.title && show_title) {
        var title = E('span', info.metadata.title)
        if (info.writable)
          Element.makeEditable(title, Map.__itemPrefix+info.path+'/edit',
            'metadata.title', null, Tr('Item.click_to_edit_title'))
        elem.appendChild(title)
      } else {
        var title = E('span')
        var basename = info.path.split("/").last()
        var editable_part = E('span', basename)
        if (info.writable)
          Element.makeEditable(editable_part,
            Map.__itemPrefix+info.path+'/edit',
            'metadata.title',
            function(base){
              if (base.length == 0) return false
              info.metadata.title = base
              return base
          }, Tr('Item.click_to_edit_title') )
        title.appendChild(editable_part)
        elem.appendChild(title)
      }
      if ( show_metadata ) {
        if (info.metadata.author) {
          metadata.appendChild(T(Tr('Item.by')+" "))
          var author = E('span', info.metadata.author)
          if (info.writable)
            Element.makeEditable(author, Map.__itemPrefix+info.path+'/edit',
              'metadata.author', null, Tr('Item.click_to_edit_author'))
          metadata.appendChild(author)
        }
        if (info.metadata.length)
          metadata.appendChild(T(" " + Object.formatTime(info.metadata.length*1000)))
        if (info.metadata.width && info.metadata.height)
          metadata.appendChild(T(" (" + info.metadata.width+"x"+info.metadata.height +
                        (info.metadata.dimensions_unit || "") + ")"))
      }
      elem.appendChild(T(" "))
      elem.appendChild(metadata)
      return elem
    },
    
    // Creates user | src | ref | date | size -div and returns it.
    parseUserInfo : function(info, win, hide_edit_link) {
      var infoDiv = E('div', null, null, 'infoDiv')
      var by = E('p')
      by.appendChild(E('a', info.owner, null, 'infoDivLink', null,
                                {href:'/users/'+info.owner}))
      if (info.source && info.source.length > 0) {
        by.appendChild(T(' | '))
        by.appendChild(E('a', Tr("Item.source"), null, 'infoDivLink', null,
                                  {href:info.source}))
      }
      if (info.referrer && info.referrer.length > 0) {
        by.appendChild(T(' | '))
        by.appendChild(E('a', Tr("Item.referrer"), null, 'infoDivLink', null,
                                  {href:info.referrer}))
      }
      by.appendChild(T(' | ' + Tr('Item.DateObject', info.created_at)))
      by.appendChild(T(' | ' + Number.mag(info.size, Tr('Item.byte_abbr'), 1)))
      infoDiv.appendChild(by)
      if (info.writable && !hide_edit_link) {
        var t = this
        var editButton = Desk.Button(
          "Item.edit",
          function(){
            if (t.editor && t.editor.windowManager != null) {
              t.editor.close()
              delete t.editor
            } else {
              t.editor = new Desk.Window(Map.__itemPrefix + info.path + '/edit')
            }
          }, {
          className: 'editButton',
          normal_image: 'images/edit_grey.png',
          hover_image: 'images/edit_yellow.png',
          down_image: 'images/edit_yellow.png',
          showText: true,
          textSide: 'right'
        })
        var deleteButton = Desk.Button(
          info.deleted ? "Item.undelete_item" : "Item.delete_item",
          function(){ t.deleteItem(win, info) }, {
          className: 'editButton',
          normal_image: 'images/delete_grey.png',
          hover_image: 'images/delete_yellow.png',
          down_image: 'images/delete_yellow.png',
          showText: true,
          textSide: 'right'
        })
        var editDiv = E("div", ' | ', null, 'editDiv',
           {display:'inline'})
        editDiv.appendChild(editButton)
        editDiv.appendChild(T(' | '))
        editDiv.appendChild(deleteButton)
        by.appendChild(editDiv)
      }
      return infoDiv
    },

    // Creates a metadata div from info.
    //
    // Returns the created metadata div (belongs to CSS class infoDiv.)
    //
    parseItemMetadata : function(info, win, hide_edit_link, hide_description, hide_metadata) {
      var infoDiv = E('div', null, null, 'infoDiv')
      infoDiv.win = win
      if (!hide_metadata) {
        var pubdata = []
        // if (info.metadata.publish_time)
        //   pubdata.push('created: ' + info.metadata.publish_time.toLocaleString())
        if (info.metadata.publisher)
          pubdata.push(Tr('Item.publisher', ': ' + info.metadata.publisher))
        if (info.metadata.album)
          pubdata.push(Tr('Item.album', ': ' + info.metadata.album))
        if (pubdata.length > 0)
          infoDiv.appendChild(E('p', pubdata.join(" | ")))
        if (info.metadata.exif) {
          var tuples = {}
          info.metadata.exif.split("\n").each(function(tup){
            var kv = tup.split("\t")
            tuples[kv[0]] = kv[1]
          })
          var exifdata = []
          if (tuples['Date and Time']) {
            var dc = tuples['Date and Time'].split(/[^0-9]/)
            var d = new Date(dc[0], dc[1], dc[2], dc[3], dc[4], dc[5])
            exifdata.push(Tr("Item.date_taken", ": " +
                                        Tr("Item.DateObject", d)))
          }
          if (tuples.Manufacturer)
            exifdata.push(Tr("Item.camera", ": " + tuples.Model +
                          ", " + Tr("Item.manufacturer", ": " + tuples.Manufacturer)))
          if (tuples.Software)
            exifdata.push(Tr("Item.software", ": " + tuples.Software))
          exifdata.each(function(pd){
            infoDiv.appendChild(E('p', pd))
          })
        }
      }
      if (info.metadata.description && !hide_description) {
        var desc = E('p')
        desc.appendChild(T(info.metadata.description))
        infoDiv.appendChild(desc)
      }
  //     infoDiv.appendChild(E('pre', info.metadata.exif))
      return infoDiv
    },

    deleteItem : function(win, info) {
      var method = info.deleted ? '/undelete' : '/delete'
      var url = Map.__itemPrefix + info.path + method
      new Ajax.Request(url, {
        onSuccess : function(res){
          Map.forceUpdate()
          if (win && !info.deleted) win.close()
          else if (win) win.setSrc(win.src)
        },
        onFailure: function(res){
          alert( Tr("Item.delete_failed") )
        }
      })
    },

    createViewer : function(info,win) {
      var viewer
      var group = 'default'
      try {
        if (['image/jpeg','image/png','image/gif'].include(info.mimetype)) {
          viewer = this.makeImageViewer(info,win)
          group = 'images'
        } else if (info.mimetype.split("/")[0] == 'video') {
          viewer = this.makeVideoViewer(info,win)
          group = 'videos'
        } else if (info.mimetype == 'application/x-flash-video') {
          viewer = this.makeFlashVideoViewer(info,win)
          group = 'videos'
        } else if (info.mimetype.split("/")[0] == 'audio') {
          viewer = this.makeAudioViewer(info,win)
          group = 'music'
        } else if (info.mimetype == 'text/html') {
          viewer = this.makeHTMLViewer(info,win)
          group = 'HTML'
        } else if (info.mimetype.split("/")[0] == 'text') {
          viewer = this.makeTextViewer(info,win)
          group = 'text'
        } else {
          viewer = this.makeThumbViewer(info,win)
          group = info.mimetype.split("/")[0]
        }
      } catch(e) {
        console.log('hälärm', e)
      }
      win.setGroup(Tr('WindowGroup.'+group))
      return viewer
    },

    makeUserInfoDiv : function(info) {
    },

    makeMetadataDiv : function(info) {
    },

    makeImageViewer : function(info,win) {
      this.easyMove = true
      var d = E('div')
      d.style.lineHeight = '0px'
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
      i.onclick = function(e) {
        if (Event.isLeftClick(e) &&
            Math.abs(this.downX - e.clientX) < 3 &&
            Math.abs(this.downY - e.clientY) < 3 &&
            this.scaled
        ) {
          i.toggleOriginalSize(e)
          if (this.originalSize) {
            this.style.cursor = '-moz-zoom-out'
          } else {
            this.style.cursor = '-moz-zoom-in'
          }
        }
      }
      i.style.cursor = 'move'
      i.onmousemove = function(e) {
        if (this.scaled) {
          i.style.cursor = 'move'
          if (this.cursorTimeout) clearTimeout(this.cursorTimeout)
          this.cursorTimeout = setTimeout(function() {
            if (this.originalSize) {
              this.style.cursor = '-moz-zoom-out'
            } else {
              this.style.cursor = '-moz-zoom-in'
            }
          }.bind(this), 500)
        }
      }
/*      i.ondblclick = function(e){
        if (Event.isLeftClick(e) &&
            Math.abs(this.downX - e.clientX) < 3 &&
            Math.abs(this.downY - e.clientY) < 3) win.close()
      }*/
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
      i.scaled = false
      var ic = false
      if (i.width < info.metadata.width || i.height < info.metadata.height) {
        i.scaled = true
        if (navigator.userAgent.match(/rv:1\.[78].*Gecko/)) {
          ic = E('canvas')
          if (ic.getContext) {
            ic.style.display = 'block'
            ic.width = iw
            ic.height = ih
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
      i.toggleOriginalSize = function(e) {
        if (!this.scaled) return
        var fac = info.metadata.width / iw
        if (this.originalSize) {
          var x = e.layerX
          var y = e.layerY - this.offsetTop/fac
          var rx = x/fac
          var ry = y/fac
          win.setX(win.x - (rx-x))
          win.setY(win.y - (ry-y))
          this.width = iw
          this.height = ih
/*          if (win.x < 0) win.setX(0)
          if (win.y < 0) win.setY(0)*/
          win.setY(win.y+1)
          setTimeout(function(){
            win.setY(win.y-1)
          }, 0)
          if (ic) {
            ic.style.display = 'block'
            ic.style.position = 'static'
            this.style.position = 'absolute'
            this.style.opacity = 0
          }
        } else {
          var x = e.layerX
          var y = e.layerY
          var rx = x*fac
          var ry = y*fac
          win.setX(win.x - (rx-x))
          win.setY(win.y - (ry-y))
          this.width = info.metadata.width
          this.height = info.metadata.height
          if (ic) {
            ic.style.display = 'none'
            ic.style.position = 'absolute'
            this.style.position = 'static'
            this.style.opacity = 1
          }
        }
        this.originalSize = !this.originalSize
      }
      win.content.removeChild(i)
      d.appendChild(i)
      return d
    },
    
    makeVideoViewer : function(info) {
      var i = E('embed')
      i.width = info.metadata.width
      i.height = info.metadata.height
      i.src = Map.__filePrefix + info.path
      i.setAttribute("type", "application/x-mplayer2")
      return i
    },

    makeFlashVideoViewer : function(info) {
      var i = E('div', '<a href="http://www.macromedia.com/go/getflashplayer">Get Flash</a> to see this player.')
      var so = new SWFObject("/scripts/flv_player/flvplayer.swf","player","320","260","7")
      so.addParam("allowfullscreen","true")
      so.addVariable("file", Map.__filePrefix + info.path)
      so.write(i)
      return i
    },

    makeAudioViewer : function(info, win) {
      if (soundManager && !soundManager._disabled) {
        var i = A(Map.__filePrefix + info.path, info.path)
      } else {
        var i = E('embed')
        i.width = 400
        i.height = 16
        i.src = Map.__filePrefix + info.path
        i.setAttribute("type", info.mimetype)
      }
      return i
    },

    makeHTMLViewer : function(info, win) {
      this.html = Object.extend({}, Mimetype['html'])
      this.embed = this.html.makeEmbed(Map.__filePrefix + info.path)
      this.html.init(Map.__filePrefix + info.path, win)
      return this.embed
    },

    makeTextViewer : function(info, win) {
      return this.makeHTMLViewer(info, win)
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

  editor : {
    mimetype : 'editor',
    makeEmbed : function(src) {
      return E('div')
    },
    
    init : function(src, win) {
      new Ajax.Request(src.replace(/edit$/, 'json'), {
        method : 'get',
        onSuccess : function(res) {
          try {
            var info = res.responseText.evalJSON()
            win.setGroup(Tr('WindowGroup.editors'))
            win.setTitle(Tr('Item.Editing', info.path.split("/").last()))
            win.content.appendChild(this.itemEditForm(info, win))
          } catch(e) { console.log(e) }
        }.bind(this)
      })
    },

    itemKeys : [
      {name:'source', type:['url']},
      {name:'referrer', type:['url']},
      {name:'tags', type:['autoComplete', 'tags']},
      {name:'sets', type:['listOrNew', 'sets', true]},
      {name:'groups', type:['listOrNew', 'groups', true]}
    ],

    metadataKeys : [
      {name:'title', type:['string']},
      {name:'author', type:['autoComplete', 'authors']},
      {name:'publisher', type:['autoComplete', 'publishers']},
      {name:'publish_time', type:['time']},
      {name:'description', type:['text']},
      {name:'genre', type:['string']},
      {name:'location', type:['location']}
      /*,
      {name:'album', type:['listOrNew', 'albums']},
      {name:'tracknum', type:['intInput']} */
    ],

    itemEditForm : function(info, win) {
      var editor = E('div', null, null, 'editor')
      var ef = E("form")
      ef.method = 'POST'
      ef.action = Map.__itemPrefix + info.path + '/edit'
      obj = new Object()
      var d = E('span')
      d.style.display = 'block'
      d.style.position = 'relative'
      d.style.width = '100%'
      d.style.height = Math.max(parseInt(editor.style.height),
                                parseInt($(editor).getComputedStyle().minHeight)) - 64 + 'px'
      d.style.overflow = 'auto'
      var tb = E('table')
      tb.width = "100%"
      d.appendChild(tb)
      var tr = E('tr')
      tr.vAlign = 'top'
      tb.appendChild(tr)
      var td = E('td')
      td.width = "50%"
      tr.appendChild(td)
      td.appendChild(E('h4', Tr('Item.item')))
      var dd = E('div')
      td.appendChild(dd)
      dd.appendChild(E("h5", Tr('Item.filename')))
      dd.appendChild(E("input", null,null,null,null,
        { type: 'text',
          name: 'filename',
          value: info.path.split("/").last().split(".").slice(0,-1).join(".")
        }))
      this.itemKeys.each(function(i) {
        var args = i.type.slice(1)
        var ed
        dd.appendChild(E("h5", Tr('Item.'+i.name)))
        if (i.name == 'tags') {
          ed = Editors[i.type[0]](i.name, info[i.name].join(", "), args)
        } else if (i.type[0] == 'list' || i.type[0] == 'listOrNew') {
          var list_name = args.shift()
          ed = E('span')
          new Ajax.Request('/'+list_name+'/json', {
            method : 'get',
            onSuccess: function(res){
            try {
              var items = res.responseText.evalJSON()
              var list_parse = function(it){
                return ((typeof it == 'string') ? it : it.name + ':' + it.namespace)
              }
              var poss_vals = items.map(list_parse)
              var values = ((typeof info[i.name] == 'string') ?
                            info[i.name] : info[i.name].map(list_parse))
              args = [poss_vals].concat(args)
              ed.appendChild(Editors[i.type[0]](i.name, values, args))
            } catch(e) {
              console.log(e)
            }
            }
          })
        } else {
          ed = Editors[i.type[0]](i.name, info[i.name], args)
        }
        if (i.type[0] == 'location') {
          ed.mapAttachNode = editor
          ed.mapTop = $(editor).getComputedStyle().top
          ed.mapLeft = (parseInt($(editor).getComputedStyle().left) +
              Math.max(parseInt($(editor).getComputedStyle().width),
                        parseInt($(editor).getComputedStyle().minWidth)) + 'px')
        }
        dd.appendChild(ed)
      })
      td = E('td')
      td.width = "50%"
      tr.appendChild(td)
      td.appendChild(E('h4', Tr('Item.metadata')))
      dd = E('div')
      td.appendChild(dd)
      this.metadataKeys.each(function(i) {
        var args = i.type.slice(1)
        var ed
        dd.appendChild(E("h5", Tr('Item.'+i.name)))
        if (i.type[0] == 'list' || i.type[0] == 'listOrNew') {
          var list_name = args.shift()
          ed = E('span')
          new Ajax.Request('/'+list_name+'/json', {
            method : 'get',
            onSuccess: function(res){
            try {
              var items = res.responseText.evalJSON()
              var list_parse = function(it){ return it.name + ':' + it.namespace }
              var poss_vals = items.map(list_parse)
              var values = info.metadata[i.name].map(list_parse)
              args = [values, poss_vals].concat(args)
              ed.appendChild(Editors[i.type[0]]('metadata.'+i.name, info.metadata[i.name], args))
            } catch(e) {
              console.log(e)
            }
            }
          })
        } else {
          ed = Editors[i.type[0]]('metadata.'+i.name, info.metadata[i.name], args)
        }
        if (i.type[0] == 'location') {
          ed.mapAttachNode = editor
          ed.mapTop = $(editor).getComputedStyle().top
          ed.mapLeft = (parseInt($(editor).getComputedStyle().left) +
              Math.max(parseInt($(editor).getComputedStyle().width),
                        parseInt($(editor).getComputedStyle().minWidth)) + 'px')
        }
        dd.appendChild(ed)
      })
      ef.appendChild(d)
      var es = E('div', null, null, 'editorSubmit')
      var cancel = E('input', null, null, null, null,
        {type:'reset', value:Tr('Item.cancel')})
      cancel.onclick = function() {
        win.close()
      }
      var done = E('input', null, null, null, null,
        {type:'submit', value:Tr('Item.done')})
      ef.onsubmit = function(e) {
        Event.stop(e)
        new Ajax.Request(ef.action, {
          method: ef.method,
          parameters: $(ef).serialize(),
          onSuccess: function(res){
            var newSrc = Map.__itemPrefix +
                          info.path.split("/").slice(0, -1).join('/') + '/' +
                          ef.filename.value + '.' + info.path.split(".").slice(-1)[0] +
                          '/json'
            var oldSrc = (Map.__itemPrefix + info.path + '/json')
            var need_update = (newSrc != oldSrc)
            var wins = win.windowManager.windows
            for (var i=0; i<wins.length; i++) {
              if (wins[i].src == oldSrc) wins[i].setSrc(newSrc)
            }
            win.close()
            if (need_update)
              Map.forceUpdate()
          }
        })
      }
//       es.appendChild(cancel)
      es.appendChild(done)
      ef.appendChild(es)
      editor.appendChild(ef)
      return editor
    }
  },

  deletion : {
    mimetype : 'delete',
    makeEmbed : function(src) {
      return E('div')
    },
    
    init : function(src, win) {
      new Ajax.Request(src.replace(/delete$/, 'json'), {
        method : 'get',
        onSuccess : function(res) {
          try {
            var info = res.responseText.evalJSON()
            win.setGroup(Tr('WindowGroup.deletions'))
            win.setTitle(Tr('Item.Deleting', info.path))
            this.deleteItem(win, info)
          } catch(e) { console.log(e) }
        }.bind(this)
      })
    },

    deleteItem : function(win, info) {
      var url = Map.__itemPrefix + info.path + '/delete'
      new Ajax.Request(url, {
        onSuccess : function(res){
          Map.forceUpdate()
          if (win) win.close()
        },
        onFailure: function(res){
          win.content.appendChild( T(Tr("Item.delete_failed")) )
        }
      })
    }
  },

  undeletion : {
    mimetype : 'undelete',
    makeEmbed : function(src) {
      return E('div')
    },
    
    init : function(src, win) {
      new Ajax.Request(src.replace(/undelete$/, 'json'), {
        method : 'get',
        onSuccess : function(res) {
          try {
            var info = res.responseText.evalJSON()
            win.setGroup(Tr('WindowGroup.undeletions'))
            win.setTitle(Tr('Item.Undeleting', info.path))
            this.deleteItem(win, info)
          } catch(e) { console.log(e) }
        }.bind(this)
      })
    },

    deleteItem : function(win, info) {
      var url = Map.__itemPrefix + info.path + '/undelete'
      new Ajax.Request(url, {
        onSuccess : function(res){
          Map.forceUpdate()
          if (win) win.close()
        },
        onFailure: function(res){
          win.content.appendChild( T(Tr("Item.undelete_failed")) )
        }
      })
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
      var container = E('div')
      var cover = E('div')
      var e = E('iframe')
      e.style.backgroundColor = 'white'
      e.src = src
      cover.style.width = e.style.width = '600px'
      cover.style.height = e.style.height = '400px'
      e.style.zIndex = 0
      cover.style.position = 'absolute'
      cover.style.display = 'block'
      cover.style.zIndex = -1
      this.cover = cover
      this.embed = e
      container.style.lineHeight = '0px'
      container.appendChild(cover)
      container.appendChild(e)
      return container
    },
    init : function(src, win) {
      win.addListener('resize', function(e){
        this.cover.style.width = this.embed.style.width = win.contentElement.style.width
        this.cover.style.height = this.embed.style.height = (parseInt(win.contentElement.style.height) - 21) + 'px'
      }.bind(this))
      win.addListener('dragStart', function() {
        this.cover.style.zIndex = 1
      }.bind(this))
      win.addListener('dragEnd', function() {
        this.cover.style.zIndex = -1
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
    json : ['json'],
    editor : ['edit'],
    deletion : ['delete'],
    undeletion : ['undelete']
  }),
  
  guess : function(src) {
    var base = src.split("/").last()
    if (['json', 'edit', 'delete', 'undelete'].include(base))
      var ext = base
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


