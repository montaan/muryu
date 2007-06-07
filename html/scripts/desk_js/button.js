Desk.Button = function(name, onclickHandler, config){
  // The button is a regular link.
  var button = E('a', null, null, 'button '+name)
  button.title = Tr('Button.'+name)

  // A link that goes nowhere.
  button.href = 'javascript:void(null)'

  // We use the name to set up the image URLs.
  button.normal_image = Desk.Button.buttonDir + name + '.png'
  button.hover_image = Desk.Button.buttonDir + name + '_hover.png'
  button.down_image = Desk.Button.buttonDir + name + '_down.png'
  button.onclickHandler = onclickHandler

  // If you want to use something other
  // than the default image names,
  // pass them in the config object.
  if (config) Object.extend(button, config)

  if (button.showText)
    button.textElem = T(Tr('Button.'+name))
    
  if (button.textElem && button.textSide != 'right')
    button.appendChild(button.textElem)

  if (button.showImage != false) {
    // Set up the button image.
    button.image = E('img')
    button.image.alt = Tr('Button.'+name)
    button.image.title = Tr('Button.'+name)
    button.image.style.border = '0px'
    button.image.onload = function() {
      button.image.onload = false
      // button.image.style.width = (this.width / 6) + 'ex'
      button.image.style.height = (this.height / 6) + 'ex'
    }
    button.image.src = button.normal_image
    button.appendChild(button.image)
  }
  
  if (button.textElem && button.textSide == 'right')
    button.appendChild(button.textElem)

  // Call toggle to make down normal and normal down.
  button.toggle = function(){
    if (!this.image) return
    if (this.image.src == this.normal_image)
      this.image.src = this.down_image
    else if (this.image.src == this.down_image)
      this.image.src = this.normal_image
    var tmp = this.down_image
    this.down_image = this.normal_image
    this.normal_image = tmp
  }

  if (button.image) {
    // Eventhandlers for lighting up the button on hover.
    button.addEventListener('mouseover',
      function(e){ this.image.src = this.hover_image }, false)
    button.addEventListener('mouseout',
      function(e){ this.image.src = this.normal_image }, false)

    // Eventhandlers for pushing the button down and clicking.
    button.addEventListener('mousedown', function(e){
      this.image.src = this.down_image
      Event.stop(e)
    }, false)
  }
  button.addEventListener('click', function(e){
    this.onclickHandler(this, e)
    if (this.image) this.image.src = this.normal_image
    Event.stop(e)
  }, false)

  return button
}
Desk.Button.buttonDir = 'buttons/'


