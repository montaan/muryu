Desk.Button = function(name, onclickHandler, config){
  // The button is a regular link.
  var button = E('a', null, null, 'button '+name)
  button.title = Tr('Button.'+name)
  button.normalTitle = name

  // A link that goes nowhere.
  button.href = 'javascript:void(null)'

  // We use the name to set up the image URLs.
  button.ext = (config && config.svg) ? 'svg' : 'png'
  button.normal_image = Desk.Button.buttonDir + name + '.' + button.ext
  button.hover_image = Desk.Button.buttonDir + name + '_hover.' + button.ext
  button.down_image = Desk.Button.buttonDir + name + '_down.' + button.ext
  button.down_normal_image = Desk.Button.buttonDir + name + '_down.' + button.ext
  button.down_hover_image = Desk.Button.buttonDir + name + '_hover.' + button.ext
  button.down_down_image = Desk.Button.buttonDir + name + '.' + button.ext
  button.onclickHandler = onclickHandler

  // If you want to use something other
  // than the default image names,
  // pass them in the config object.
  if (config) Object.extend(button, config)

  if (button.downTitle) {
    button.down_normal_image = Desk.Button.buttonDir + button.downTitle + '.' + button.ext
    button.down_hover_image = Desk.Button.buttonDir + button.downTitle + '_hover.' + button.ext
    button.down_down_image = Desk.Button.buttonDir + button.downTitle + '_down.' + button.ext
  }

  if (button.showText)
    button.textElem = E('span', Tr('Button.'+name))
    
  if (button.textElem && button.textSide != 'right')
    button.appendChild(button.textElem)

  if (button.showImage != false) {
    button.image = E('img')
    button.image.alt = Tr('Button.'+name)
    button.image.title = Tr('Button.'+name)
    button.image.style.border = '0px'
    button.image.onload = function() {
      this.onload = false
      button.image.style.height = (this.height / 6) + 'ex'
      if (button.svg) button.image.style.width = (this.width / 6) + 'ex'
    }
    button.image.src = button.normal_image
    button.appendChild(button.image)
  }
  
  if (button.textElem && button.textSide == 'right')
    button.appendChild(button.textElem)

  button.down = false
  // Call toggle to toggle button down state
  button.toggle = function(){
    if (this.down)
      this.pull()
    else
      this.push()
  }
  button.setImage = function(img){
    this.image.src = img
  }
  button.push = function() {
    this.down = true
    if (this.downTitle) {
      this.title = Tr('Button.'+this.downTitle)
      if (this.image)
        this.image.title = this.image.alt = this.title
      if (button.showText)
        button.textElem.innerHTML = Tr('Button.'+this.downTitle)
    }
    if (!this.image) return
    this.setImage(this.down_normal_image)
  }
  button.pull = function() {
    this.down = false
    if (this.downTitle) {
      this.title = Tr('Button.'+this.normalTitle)
      if (this.image)
        this.image.title = this.image.alt = this.title
      if (button.showText)
        button.textElem.innerHTML = Tr('Button.'+this.downTitle)
    }
    if (!this.image) return
    this.setImage(this.normal_image)
  }

  if (button.image) {
    // Eventhandlers for lighting up the button on hover.
    button.addEventListener('mouseover',
      function(e){ this.setImage(this.down ? this.down_hover_image : this.hover_image) }, false)
    button.addEventListener('mouseout',
      function(e){ this.setImage(this.down ? this.down_normal_image : this.normal_image) }, false)

    // Eventhandlers for pushing the button down and clicking.
    button.addEventListener('mousedown', function(e){
      this.setImage(this.down ? this.down_down_image : this.down_image)
      Event.stop(e)
    }, false)
  }
  button.addEventListener('click', function(e){
    var d = this.down
    this.onclickHandler(this, e)
    if (this.image && d == this.down)
      this.setImage(this.down ? this.down_normal_image : this.normal_image)
    Event.stop(e)
  }, false)

  return button
}
Desk.Button.buttonDir = 'buttons/'


