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
  'Date' : function(d){
    weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    return (weekdays[d.getDay()] + ', ' + months[d.getMonth()] + ' ' +
            d.getDate() + ', ' + (d.getYear() + 1900) + ' ' +
            (d.getHours()%13).toString().rjust(2, '0') + ':' +
            d.getMinutes().toString().rjust(2, '0') + ':' +
            d.getSeconds().toString().rjust(2, '0') + ' ' +
            (d.getHours() < 13 ? 'am' : 'pm'))
  },
  'Time' : function(num) {
    var str = Object.formatTime(num)
    var smh = str.split(":").reverse()
    var nstr = ""
    var s = smh[0]
    nstr = s+'s'+nstr
    var m = smh.length > 1 && smh[1]
    if (m) nstr = m+'m'+nstr
    var h = smh.length > 2 && smh[2]
    if (h) nstr = h+'h'+nstr
    return nstr.strip()
  },
  'FuzzyTime' : function(num) {
    var str = Object.formatTime(num)
    var smh = str.split(":").reverse()
    var nstr = ""
    var s = smh.length == 0 && smh[0]
    if (s) return '<1min'
    var m = smh.length > 1 && smh[1]
    if (m) nstr = m+'min '+nstr
    var h = smh.length > 2 && smh[2]
    if (h) nstr = h+'h '+nstr
    return '~' + nstr.strip()
  },
  'Item.welcome' : function(name){
    return 'Welcome, '+name
  },
  'Item.sign_in' : 'Log in',
  'Item.register' : 'Create account',
  'Item.sign_out' : 'Log out',
  'Item.username' : 'Account name',
  'Item.password' : 'Password',
  'Item.words' : function(c) { return c + ' words' },
  'Item.pages' : function(c) { return c + ' pages' },
  'Item.by' : 'by',
  'Item.author' : 'Author',
  'Item.date_taken' : 'Created at',
  'Item.camera' : 'Camera',
  'Item.manufacturer' : 'Manufacturer',
  'Item.software' : 'Software',
  'Button.Item.edit' : 'Edit metadata',
  'Button.Item.delete_item' : 'Delete',
  'Button.Item.undelete_item' : 'Undelete',
  'Item.filename' : 'Filename',
  'Item.source' : 'Source',
  'Item.referrer' : 'Referrer',
  'Item.Download' : 'Download',
  'Item.AsJPEG' : 'as JPEG',
  'Item.AsText' : 'as text',
  'Item.AsPDF' : 'as PDF',
  'Item.sets' : 'Folders',
  'Item.groups' : 'Groups',
  'Item.tags' : 'Tags',
  'Item.mimetype' : 'File type',
  'Item.deleted' : 'Deleted',
  'Item.title' : 'Title',
  'Item.publisher' : 'Publisher',
  'Item.publish_time' : 'Publish time',
  'Item.description' : 'Description',
  'Item.location' : 'Location',
  'Item.genre' : 'Genre',
  'Item.album' : 'Album',
  'Item.tracknum' : 'Track number',
  'Item.album_art' : 'Album art',
  'Item.cancel' : 'Cancel',
  'Item.done' : 'Save',
  'Button.Item.show_EXIF' : 'Show EXIF data',
  'Item.edit_failed' : 'Saving edits failed',
  'Item.delete_failed' : 'Deleting item failed',
  'Item.loading_tile_info' : 'Loading tile info failed',
  'Item.loading_item_info' : 'Loading item info failed',
  'Item.byte_abbr' : 'B',
  'Item.click_to_edit_title' : 'Click to edit item title',
  'Item.click_to_edit_author' : 'Click to edit item author',
  'Item.item' : 'Item',
  'Item.organization' : 'Organization',
  'Item.metadata' : 'Metadata',
  'Item.dimensions.undefined' : function(w,h) {
    return parseInt(w) + 'x' + parseInt(h)
  },
  'Item.dimensions.mm' : function(w,h) {
    return parseInt(w) + 'x' + parseInt(h) + 'mm'
  },
  'Item.dimensions.px' : function(w,h) {
    return parseInt(w) + 'x' + parseInt(h) + 'px'
  },
  'Item.dimensions.pt' : function(w,h) {
    return parseInt(w) + 'x' + parseInt(h) + 'pt'
  },
  
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
  'WindowGroup.documents' : 'documents',
  'WindowGroup.other' : 'others'
})
Tr.addTranslations('en-GB', {
  'Date' : function(d){
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
  'Date' : function(d){
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
  'Item.words' : function(c){ return c + ' sanaa' },
  'Item.pages' : function(c) { return c + ' sivua' },
  'Item.by' : '-',
  'Item.author' : 'Tekijä',
  'Item.date_taken' : 'Luotu',
  'Item.camera' : 'Kamera',
  'Item.manufacturer' : 'Valmistaja',
  'Item.software' : 'Ohjelmisto',
  'Button.Item.edit' : 'Muokkaa tietoja',
  'Button.Item.delete_item' : 'Poista',
  'Button.Item.undelete_item' : 'Tuo takaisin',
  'Item.filename' : 'Tiedostonimi',
  'Item.source' : 'Lähde',
  'Item.referrer' : 'Viittaaja',
  'Item.sets' : 'Kansiot',
  'Item.groups' : 'Ryhmät',
  'Item.tags' : 'Asiasanat',
  'Item.mimetype' : 'Tiedostomuoto',
  'Item.deleted' : 'Poistettu',
  'Item.title' : 'Nimeke',
  'Item.publisher' : 'Julkaisija',
  'Item.publish_time' : 'Julkaisuaika',
  'Item.description' : 'Kuvaus',
  'Item.location' : 'Sijainti',
  'Item.genre' : 'Tyylilaji',
  'Item.album' : 'Albumi',
  'Item.tracknum' : 'Raidan numero',
  'Item.album_art' : 'Kansitaide',
  'Item.cancel' : 'Peruuta',
  'Item.done' : 'Tallenna',
  'Button.Item.show_EXIF' : 'Näytä EXIF-tiedot',
  'Item.edit_failed' : 'Muutosten tallentaminen epäonnistui',
  'Item.delete_failed' : 'Poisto epäonnistui',
  'Item.loading_tile_info' : 'Tiilen tietojen lataaminen epäonnistui',
  'Item.loading_item_info' : 'Kohteen tietojen lataaminen epäonnistui',
  'Item.byte_abbr' : 't',
  'Item.click_to_edit_title' : 'Napsauta muokataksesi nimekettä',
  'Item.click_to_edit_author' : 'Napsauta muokataksesi tekijän nimeä',
  'Item.item' : 'Kohde',
  'Item.organization' : 'Järjestely',
  'Item.metadata' : 'Sisältö',
  
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
  'WindowGroup.documents' : 'asiakirjat',
  'WindowGroup.other' : 'muut'
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
      var s = src.split("/")
      win.setTitle("Loading " + s[s.length - 2] + "...")
      new Ajax.Request(src, {
        method : 'get',
        onSuccess : function(res) {
          try {
            var info = res.responseText.evalJSON()
            win.setTitle(this.parseTitle(info, win))
            win.content.appendChild(this.parseUserInfo(info, win))
            win.content.appendChild(this.createViewer(info, win))
            win.content.appendChild(this.parseItemMetadata(info, win))
            win.setSize(win.element.clientWidth, win.element.clientHeight)
            win.newEvent('contentChange', {value: win.content})
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
/*        if (info.writable)
          Element.makeEditable(title, '/items/'+info.path+'/edit',
            'metadata.title', null, Tr('Item.click_to_edit_title'))*/
        elem.appendChild(title)
      } else {
        var title = E('span')
        var basename = info.path.split("/").last()
        var editable_part = E('span', basename)
/*        if (info.writable)
          Element.makeEditable(editable_part,
            '/items/'+info.path+'/edit',
            'metadata.title',
            function(base){
              if (base.length == 0) return false
              info.metadata.title = base
              return base
          }, Tr('Item.click_to_edit_title') )*/
        title.appendChild(editable_part)
        elem.appendChild(title)
      }
      if ( show_metadata ) {
        if (info.metadata.author) {
          metadata.appendChild(T(Tr('Item.by')+" "))
          var author = E('span', info.metadata.author)
/*          if (info.writable)
            Element.makeEditable(author, '/items/'+info.path+'/edit',
              'metadata.author', null, Tr('Item.click_to_edit_author'))*/
          metadata.appendChild(author)
        }
        var mda = []
        if (info.metadata.words)
          mda.push(Tr('Item.words', info.metadata.words))
        if (info.metadata.length)
          mda.push(Tr('Time', info.metadata.length*1000))
        else if (info.metadata.words)
          mda.push(Tr('FuzzyTime', (info.metadata.words/5)*1000))
        if (info.metadata.pages)
          mda.push(Tr('Item.pages', info.metadata.pages))
        if (info.metadata.page_size)
          mda.push(info.metadata.page_size)
        else if (info.metadata.width && info.metadata.height)
          mda.push(
            Tr('Item.dimensions.'+info.metadata.dimensions_unit,
               info.metadata.width, info.metadata.height))
        mda.push(Number.mag(info.size, Tr('Item.byte_abbr'), 1))
      }
      metadata.appendChild(T(" ("+mda.join(", ")+") "))
      elem.appendChild(T(" "))
      elem.appendChild(metadata)
      return elem.textContent
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
      by.appendChild(T(" | " + Tr('Date', info.created_at)))
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
              t.editor = new Desk.Window('/items/' + info.path + '/edit')
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
        var editDiv = E("div", null, null, 'editDiv')
        editDiv.appendChild(editButton)
        editDiv.appendChild(T(' | '))
        editDiv.appendChild(deleteButton)
        by.appendChild(editDiv)
      }
      var links = E('div')
      links.append(
        Tr('Item.Download')+': ',
        A('/files/' + info.path, info.path.split("/").last())
      )
      if (info.mimetype != 'image/jpeg') {
      links.append(
          ' | ',
          A("/items/"+info.path+"/image?size=full", Tr('Item.AsJPEG'))
        )
      }
      if ((info.mimetype.match(this.documentRegex) || info.mimetype.match(this.textRegex)) && !(info.mimetype == 'text/plain')) {
        links.append(
          ' | ',
          A("/items/"+info.path+"/text", Tr('Item.AsText'))
        )
      }
      if ((info.mimetype.match(this.documentRegex) || info.mimetype.match(this.textRegex)) && !(info.mimetype == 'application/pdf')) {
        links.append(
          ' | ',
          A("/items/"+info.path+"/pdf", Tr('Item.AsPDF'))
        )
      }
      links.style.marginBottom = '3px'
      links.style.borderTop = '1px dotted grey'
      infoDiv.append(links)
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
                                        Tr("Date", d)))
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
        var desc = E('div')
        var lines = info.metadata.description.split("\n")
        lines.each(function(l){
          desc.appendChild(E('p', l))
        })
        infoDiv.appendChild(desc)
      }
      if (info.metadata.exif && info.metadata.exif.length > 0) {
        var showExif = Desk.Button('Item.show_EXIF', function(){
          if (infoDiv.exifWindow && infoDiv.exifWindow.windowManager) {
            infoDiv.exifWindow.close()
            delete infoDiv.exifWindow
          } else {
            var exifDiv = E('div', null, null, 'exif')
            var exifTable = E('table')
            var tags = info.metadata.exif.split("\n")
            for (var i=0; i<tags.length; i++) {
              var tr = E('tr')
              tr.valign = 'top'
              var tag_val = tags[i].split("\t")
              tr.appendChild(E('td', E('h4', tag_val[0])))
              tr.appendChild(E('td', E('p', tag_val[1])))
              exifTable.appendChild(tr)
            }
            exifDiv.appendChild(exifTable)
            infoDiv.exifWindow = new Desk.Window(exifDiv, {
              title : info.path.split("/").last(),
              transient : true,
              cropToScreen : true
            })
          }
        }, {
          showImage : false, showText : true
        })
        showExif.style.display = 'block'
        infoDiv.appendChild(showExif)
      }
      infoDiv.style.width = win.contentElement.offsetWidth + 'px'
      return infoDiv
    },

    deleteItem : function(win, info) {
      var method = info.deleted ? '/undelete' : '/delete'
      var url = '/items/' + info.path + method
      new Ajax.Request(url, {
        onSuccess : function(res){
//           Map.forceUpdate()
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
        } else if (info.mimetype == 'application/x-shockwave-flash') {
          viewer = this.makeFlashViewer(info,win)
          group = 'flash'
        } else if (info.mimetype == 'application/x-flash-video') {
          viewer = this.makeFlashVideoViewer(info,win)
          group = 'videos'
        } else if (info.mimetype.split("/")[0] == 'audio') {
          viewer = this.makeAudioViewer(info,win)
          group = 'music'
        } else if (info.mimetype == 'text/html') {
          viewer = this.makeImageViewer(info,win)
          group = 'HTML'
        } else if (info.mimetype.match(this.textRegex)) {
          viewer = this.makeTextViewer(info,win)
          group = 'text'
        } else if (info.mimetype.match(this.documentRegex)) {
          viewer = this.makeDocumentViewer(info,win)
          group = 'documents'
        } else {
          viewer = this.makeImageViewer(info,win)
          group = 'other'
        }
      } catch(e) {
        console.log('hälärm', e)
      }
      win.setGroup(Tr('WindowGroup.'+group))
      return viewer
    },

    documentRegex : /pdf|postscript|powerpoint|vnd\.oasis\.opendocument|msword|ms-excel|rtf|x-tex|template|stardivision|comma-separated-values|dbf|vnd\.sun\.xml/,
    
    textRegex : /^text/,

    makeUserInfoDiv : function(info) {
    },

    makeMetadataDiv : function(info) {
    },

    makeImageViewer : function(info,win) {
      win.easyMove = true
      var d = E('div')
      // d.style.lineHeight = '0px'
      var i = E('img')
      i.style.display = 'block'
      var iw = info.metadata.width || 1024
      var ih = info.metadata.height || 1024
      if (info.metadata.dimensions_unit && info.metadata.dimensions_unit == 'mm') {
        var larger = Math.max(iw, ih)
        iw = 1024*iw / larger
        ih = 1024*ih / larger
      } else {
        var larger = Math.max(iw, ih)
      }
      if (larger && larger > 1024) {
        var imgWidth = 1024*iw / larger
        var imgHeight = 1024*ih / larger
      } else {
        var imgWidth = iw
        var imgHeight = ih
      }
      var mw = win.container.offsetWidth
      var mh = win.container.offsetHeight
      if (mw < (iw + 20)) {
        ih *= (mw - 20) / iw
        iw = mw - 20
      }
      var lh = 200
      if (mh < (ih + lh)) {
        iw *= (mh - lh) / ih
        ih = mh - lh
      }
      i.scaled = false
      var ic = false
      if (iw && ih && (iw < imgWidth || ih < imgHeight)) {
        i.scaled = true
        if (navigator.userAgent.match(/rv:1\.[78].*Gecko/)) {
          var ic = E('canvas')
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
      i.style.width = iw + 'px'
      i.style.height = ih + 'px'
      i.width = imgWidth
      i.height = imgHeight
      i.style.cursor = 'move'
      i.src = '/items/' + info.path + '/image'
      d.appendChild(i)
      return d
    },
    
    makeVideoViewer : function(info, win) {
      var s = E('div')
      // s.style.lineHeight = '0'
      var i = E('embed')
      i.style.display = 'block'
      s.appendChild(i)
      s.style.minHeight = (info.metadata.height + 16) + 'px'
      s.style.minWidth = (info.metadata.width) + 'px'
      s.style.height = (info.metadata.height + 16) + 'px'
      i.width = '100%'
      i.height = '100%'
      win.addListener('resize', function(ev) {
        this.style.width = win.contentElement.offsetWidth + 'px'
        var restheight = win.content.offsetHeight - parseInt(this.style.height)
        var newheight = parseInt(win.contentElement.style.height) - restheight
        this.style.height = newheight + 'px'
      }.bind(s))
      i.src = '/files/' + info.path
      i.setAttribute("scale", "aspect")
      i.setAttribute("bgcolor", "000000")
      if (navigator.userAgent.indexOf('Windows') != -1)
        i.setAttribute("type", "video/quicktime") // WMP, the scourge
      else
        i.setAttribute("type", "application/x-mplayer2")
      return s
    },

    makeFlashVideoViewer : function(info, win) {
      var s = E('div')
      // s.style.lineHeight = '0'
      var i = E('div', '<a href="http://www.macromedia.com/go/getflashplayer">Get Flash</a> to see this player.')
      if (!info.metadata.width)
        info.metadata.width = 480
      if (!info.metadata.height)
        info.metadata.height = 360
      i.style.minHeight = (info.metadata.height + 20) + 'px'
      i.style.minWidth = (info.metadata.width) + 'px'
      i.style.height = (info.metadata.height + 20) + 'px'
      win.addListener('resize', function(ev) { // this is no worky :|
        this.style.width = win.contentElement.offsetWidth + 'px'
        var restheight = win.content.offsetHeight - parseInt(this.style.height)
        var newheight = parseInt(win.contentElement.style.height) - restheight
        this.style.height = newheight + 'px'
      }.bind(i))
      s.appendChild(i)
      var so = new SWFObject("/scripts/flv_player/flvplayer.swf","player",info.metadata.width,info.metadata.height+20,"7")
      so.addParam("allowfullscreen", "true")
      so.addVariable("volume", (MusicPlayer && MusicPlayer.volume) || 100)
      so.addVariable("file", '/files/' + info.path)
      so.write(i)
      i.firstChild.style.display = 'block'
      return s
    },

    makeFlashViewer : function(info, win) {
      var s = E('div')
      // s.style.lineHeight = '0'
      var i = E('div', '<a href="http://www.macromedia.com/go/getflashplayer">Get Flash</a> to see this player.')
      if (!info.metadata.width)
        info.metadata.width = 480
      if (!info.metadata.height)
        info.metadata.height = 360
      i.style.minHeight = (info.metadata.height) + 'px'
      i.style.minWidth = (info.metadata.width) + 'px'
      i.style.height = (info.metadata.height) + 'px'
      win.addListener('resize', function(ev) { // this is no worky :|
        this.style.width = win.contentElement.offsetWidth + 'px'
        var restheight = win.content.offsetHeight - parseInt(this.style.height)
        var newheight = parseInt(win.contentElement.style.height) - restheight
        this.style.height = newheight + 'px'
      }.bind(i))
      s.appendChild(i)
      var so = new SWFObject('/files/' + info.path, "player",
        '100%','100%',"7")
      so.write(i)
      i.firstChild.style.display = 'block'
      return s
    },

    makeAudioViewer : function(info, win) {
      var s = E('div')
      // s.style.lineHeight = '0'
      var i = E('embed')
      i.style.display = 'block'
      s.appendChild(i)
      i.width = '100%'
      i.height = 16
      i.setAttribute("volume", (MusicPlayer && MusicPlayer.volume) || 100)
      i.src = '/files/' + info.path
      i.setAttribute("type", info.mimetype)
      return s
    },

    makeHTMLViewer : function(info, win) {
      this.html = Object.extend({}, Mimetype['html'])
      this.embed = this.html.makeEmbed('/files/' + info.path)
      this.html.init('/files/' + info.path, win)
      return this.embed
    },

    makeTextViewer : function(info, win) {
      this.text = Object.extend({}, Mimetype['text'])
      this.embed = this.text.makeEmbed('/files/' + info.path)
      this.text.init('/files/' + info.path, win)
      return this.embed
    },

    makeDocumentViewer : function(info, win) {
      var s = this.slideshow = Suture.makePDF((win.parameters && win.parameters.index) || 0, info.path, info.metadata.pages)
      win.parameters = {index: 0}
      s.window = win
      win.slideshow = s
      var wasShaded = win.shaded
      var embed = E('div')
      embed.style.width = '600px'
      embed.style.height = '400px'
      embed.append(this.slideshow.container)
      var resizer = function() {
        var other = embed.parentNode.clientHeight - embed.clientHeight
        embed.style.width = (win.contentElement.clientWidth) + 'px'
        embed.style.height = (win.contentElement.clientHeight - other) + 'px'
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
      win.addListener('contentChange', resizer)
      win.addListener('shadeChange', resizer)
      return embed
    },

    makeThumbViewer : function(info, win) {
      var s = E('a')
      var i = E('img')
      i.style.display = 'block'
      i.style.border = '0px'
      i.src = '/items/' + info.path + '/thumbnail'
      s.appendChild(i)
      s.href = '/files/' + info.path
      return s
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
      {name:'tags', type:['autoComplete', 'tags']}
    ],

    orgKeys : [
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
      ef.action = '/items/' + info.path + '/edit'
      obj = new Object()
      var d = E('span')
      d.style.display = 'block'
      var tb = E('table')
      tb.width = "100%"
      tb.style.minWidth = '768px'
      d.appendChild(tb)
      var tr = E('tr')
      tr.vAlign = 'top'
      tb.appendChild(tr)
      var td = E('td')
      td.width = "33%"
      tr.appendChild(td)
      td.appendChild(E('h4', Tr('Item.item')))
      var dd = E('div')
      dd.style.textAlign = 'center'
      dd.style.minWidth = "256px"
      td.appendChild(dd)
      dd.appendChild(E("img", null, null, null, null, {src:'/items/' + info.path+'/thumbnail'}))
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
        if (i.name == 'tags')
          ed = Editors[i.type[0]](i.name, info[i.name].join(", "), args)
        else
          ed = Editors[i.type[0]](i.name, info[i.name], args)
        dd.appendChild(ed)
      })
      td = E('td')
      td.width = "33%"
      tr.appendChild(td)
      td.appendChild(E('h4', Tr('Item.organization')))
      dd = E('div')
      td.appendChild(dd)
      this.orgKeys.each(function(i) {
        var args = i.type.slice(1)
        var ed
        dd.appendChild(E("h5", Tr('Item.'+i.name)))
        if (i.name == 'groups') {
          var list_name = args.shift()
          ed = E('span')
          new Ajax.Request('/'+list_name+'/json', {
            method : 'get',
            onSuccess: function(res){
            try {
              var items = res.responseText.evalJSON()
              var list_parse = function(it){
                return {title: it.name + ' (owner: ' + it.owner + ')', value: it.name }
              }
              var poss_vals = items.map(list_parse)
              var values = info[i.name]
              var my_groups = []
              var admin_groups = []
              var item_groups = []
              var rest = []
              for(var j=0;j<items.length;j++) {
                var a = items[j]
                if (values.include(list_parse(a).value)) {
                  item_groups.push(a)
                } else if (a.owner == Session.storage.info.name) {
                  my_groups.push(a)
                } else if (a.writable) {
                  admin_groups.push(a)
                } else {
                  rest.push(a)
                }
              }
              if (my_groups.length > 0)
                my_groups = [{title:'My groups'}].concat(my_groups.map(list_parse).sort())
              if (admin_groups.length > 0)
                admin_groups = [{title:'Groups that I administer'}].concat(admin_groups.map(list_parse).sort())
              if (item_groups.length > 0)
                item_groups = [{title:"Item's groups"}].concat(item_groups.map(list_parse).sort())
              if (rest.length > 0)
                rest = [{title:'Groups that I am a member of'}].concat(rest.map(list_parse).sort())
              args = [item_groups.concat([{separator:true}]).concat(my_groups).concat(admin_groups).concat(rest)].concat(args)
              ed.appendChild(Editors[i.type[0]](i.name, values, args))
            } catch(e) {
              console.log(e)
            }
            }
          })
        } else if (i.name == 'sets') {
          var list_name = args.shift()
          ed = E('span')
          new Ajax.Request('/'+list_name+'/json', {
            method : 'get',
            onSuccess: function(res){
            try {
              var items = res.responseText.evalJSON()
              var list_parse = function(it){
                return (it.namespace + '/' + it.name )
              }
              var poss_vals = items.map(list_parse)
              var values = info[i.name]
              args = [poss_vals].concat(args)
              ed.appendChild(Editors[i.type[0]](i.name, values, args))
            } catch(e) {
              console.log(e)
            }
            }
          })
        } else if (i.type[0] == 'list' || i.type[0] == 'listOrNew') {
          var list_name = args.shift()
          ed = E('span')
          new Ajax.Request('/'+list_name+'/json', {
            method : 'get',
            onSuccess: function(res){
            try {
              var items = res.responseText.evalJSON()
              var list_parse = function(it){
                return ((typeof it == 'string') ? it : it.namespace + '/' + it.name )
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
        }
        dd.appendChild(ed)
      })
      td = E('td')
      td.width = "33%"
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
              var list_parse = function(it){ return it.name }
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
            var newSrc = '/items/' +
                          info.path.split("/").slice(0, -1).join('/') + '/' +
                          ef.filename.value + '.' + info.path.split(".").slice(-1)[0] +
                          '/json'
            var oldSrc = ('/items/' + info.path + '/json')
            var need_update = (newSrc != oldSrc)
            var wins = win.windowManager.windows
            for (var i=0; i<wins.length; i++) {
              if (wins[i].src == oldSrc) wins[i].setSrc(newSrc)
            }
            win.close()
            if (need_update) {
//               Muryu.mainMap.forceUpdate()
            }
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
      var url = '/items/' + info.path + '/delete'
      new Ajax.Request(url, {
        onSuccess : function(res){
//           Map.forceUpdate()
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
      var url = '/items/' + info.path + '/undelete'
      new Ajax.Request(url, {
        onSuccess : function(res){
//           Map.forceUpdate()
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
      container.style.lineHeight = '0px'
      var e = E('iframe')
      e.style.display = 'block'
      e.style.backgroundColor = 'white'
      e.src = src
      e.style.width = '600px'
      e.style.height = '400px'
      e.style.zIndex = 0
      this.embed = e
      this.container = container
      container.appendChild(e)
      return container
    },
    init : function(src, win) {
      this.resizer = function(e){
        this.embed.style.width = win.contentElement.style.width
        this.embed.style.height = parseInt(win.contentElement.style.height) - (this.container.offsetTop-win.contentElement.offsetTop) + 'px'
      }
      win.addListener('resize', this.resizer.bind(this))
      win.addListener('containerChange', this.resizer.bind(this))
      win.addListener('dragStart', function() {
        this.embed.style.visibility = 'hidden'
      }.bind(this))
      win.addListener('dragEnd', function() {
        this.embed.style.visibility = 'visible'
      }.bind(this))
    }
  },

  text : {
    mimetype : 'text',
    makeEmbed : function(src) {
      var e = E('textarea')
      e.style.display = 'block'
      e.style.backgroundColor = 'white'
      e.style.fontWeight = 'normal'
      e.style.border = '0px'
      e.style.color = 'black'
      e.style.margin = '0px'
      e.style.padding = '2px'
      e.style.width = '600px'
      e.style.height = '400px'
      new Ajax.Request( src, {
        method:'get',
        onSuccess : function(res) {
          e.append(T(res.responseText))
        }
      })
      this.embed = e
      return e
    },
    init : function(src, win) {
      this.resizer = function(e){
        this.embed.style.width = parseInt(win.contentElement.style.width) - 4 + 'px'
        this.embed.style.height = parseInt(win.contentElement.style.height) - (this.embed.offsetTop-win.contentElement.offsetTop) - 4 + 'px'
      }
      this.resizer()
      win.addListener('resize', this.resizer.bind(this))
      win.addListener('containerChange', this.resizer.bind(this))
    }
  },

  /**
    Application window.
    Calls the named function with the opened window and the string after the
    slash if any.

    // Calls MusicPlayer.initPlaylistWindow(win)
    app:MusicPlayer.initPlaylistWindow

    // Calls console.log(win, 'hello_world')
    app:console.log/hello_world
   */
  app : {
    init : function(src, win) {
      var path_param = src.split("/")
      var full_path = path_param[0].split(":")[1]
      var param = path_param.slice(1).join("/")
      var object_method = full_path.split(".")
      var object_path = object_method.slice(0,-1).join(".")
      var method_name = object_method.last()
      if (object_path.length == 0)
        window[method_name](win, param)
      else
        Object.retrieve(object_path)[method_name](win, param)
    }
  }
}

Mime = {
  extensionHandlers : new Hash({
    video : ['avi', 'mpg', 'wmv', 'mov'],
    audio : ['wav', 'ogg'],
    music : ['mp3'],
    image : ['jpg', 'jpeg', 'png', 'gif'],
    html : ['html', 'org', 'com', 'net'],
    playlist : ['m3u']
  }),
  dirHandlers : new Hash({
    json : ['json'],
    editor : ['edit'],
    deletion : ['delete'],
    undeletion : ['undelete']
  }),
  protocolHandlers : new Hash({
    app : ['app']
  }),
  
  guess : function(src) {
    var proto = src.split(":")[0]
    var base = src.split("/").last()
    if (src[src.length-1] == '/')
      var ext = 'html'
    else
      var ext = src.split('.').last().toLowerCase()
    var type = this.protocols[proto] || this.dirs[base] || this.extensions[ext]
    var mimetype = Mimetype[type] || Mimetype['html']
    return mimetype
  }
}
Mime.protocols = new Hash()
Mime.protocolHandlers.each(function(kv){
  kv[1].each(function(ext){
    Mime.protocols[ext] = kv[0]
  })
})
Mime.dirs = new Hash()
Mime.dirHandlers.each(function(kv){
  kv[1].each(function(ext){
    Mime.dirs[ext] = kv[0]
  })
})
Mime.extensions = new Hash()
Mime.extensionHandlers.each(function(kv){
  kv[1].each(function(ext){
    Mime.extensions[ext] = kv[0]
  })
})


