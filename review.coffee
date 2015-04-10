

if typeof window isnt 'undefined'
  namespace = window.review = {}
else
  namespace = module.exports

namespace.deferred = [];

$doc = $(document)
window.view_registry = {}

get_classes = (node)->
  if node.className
    classes = node.className.split ' '
  else
    classes = []
  if node.name
    classes.push node.name
  if node.id
    classes.push node.id
  classes


# Generate a view instance for this event.
# @root is the root of the entire view. If unspecified, find any view.
# @el is the contextual element the event was delegated to (bound to "this" in vanilla JS)
# @target is the event target (e.target)
get_closest_view = (el, root)->
  # Get the specific root element if a root is specified.
  if root

    $root = $(el)
    unless $root.is(root)
      $root = $root.parents(root)
  
  else # If no root was provided, use the closest one.
    while el
      for c in get_classes el
        if view_registry['.'+c]
          root = '.'+c
          $root = $(el)
          break
      el = el.parentNode  
  
  unless $root and $root.length # If no matching root was found, bail out.
    return null
  
  # Fetch the view instance if it exists.
  view_instance = $root.data 'view'
  unless view_instance # Otherwise, create it.
    view_instance ?=
      $: $root
      item: $root.data 'item'
    view_instance.__proto__ = view_registry[root]
    $root.data 'view', view_instance

  view_instance

# Binds a related set of events to an selector (not a dom element, as it may not exist).
# All events are delegated through the document, so as to decouple dom state from view definitions.
# I first saw (and stole) this idea from the bone.io framework.
#
# review.view '.root-element',
#
#   events:
#     'click .ready-for-pie': ->
#       @get_fork()
#       @get_plate()
#
#   get_fork: ->
#     @$root.addClass 'has-fork'
#
namespace.view = (root, opts)->

  opts.__proto__ = base_view
  opts.get_all = -> $(root)


  # Delegate handling an event desribed by @param specifier to @param handler.
  delegate = (specifier_raw, handler)->

    specifiers = specifier_raw.split ','
    for specifier in specifiers
      tokens = specifier.split(' ')
      event_type = tokens[0]
      selectors = [root].concat(tokens[1..]).join(' ')

      if 'string' is typeof handler
        handler = opts[handler]
    
    $doc.on event_type, selectors, (e)->
      #console.log specifier_raw
      # Apply a handler to our view.
      # Notably, we create a new instance of the view at this time which serves as a context for the event handler.
      view_instance = get_closest_view @, root
      result = handler.call(view_instance, e)
      #console.log 'event: ', specifier_raw, 'returned', result
      if result isnt false
        view_instance.sync?()
  
  $.each opts.events, delegate
  
  view_registry[root] = opts

  opts

timeout = undefined # one global sync timeout for debouncing.

base_view =
  
  parent: -> # get the parent view of this view. Views must be initialized
    node = @$.parent().get(0)
    while node
      if $(node).data 'view' # View should be initialized since this one is.
        return $(node).data 'view'
      node = node.parentNode
    null # No parent found.

  # Print some debug info (any arguments), along with arrows showing current recursion depth.
  print: ->
    x = @depth
    s = ''
    while x
      x -= 1
      s += '-> '
    console.log s,arguments
  
  # call a function after the next refresh.
  defer: (fn)->
    console.log 'deferring'
    review.deferred.push(fn)

  # Render a value to a node based on the node's type.
  syncTerminal: (node, value)->
    if node.tagName is 'INPUT'
      if node.type is 'checkbox'
        node.checked = not not value
      else # Regular inputs
        node.value = value
    else # Regular nodes.
      node.innerText = value

  # Render an array of data, typically to a list element.
  # Try to re-use old nodes if they still match the array elements.
  # I wish there were a nicer way to do this, but I suppose it's better than wiping out the nodes each update,
  # but we want to avoid flickering caused by re-creating big chunks of DOM.
  # TODO: this code is complicated enough that it needs some tests!
  syncArray: (parent_node, match)->
    tpl_node = parent_node.lastElementChild
    tpl_node.style.display = 'none' # hide the original
    
    node = parent_node.firstElementChild
    item_node = {}
    node_item = {}
    i = 0
    ii = 0
    last_ii = 0
    num_children = parent_node.children.length

    # Keep track of which children hold existing items so we can keep them around.
    while i < match.length
      ii = last_ii
      while ii < num_children - 1 # exclude template node.
        if match[i] is $(parent_node.children[ii]).data 'item'
          item_node[i] = ii
          node_item[ii] = i
          last_ii = ii
          break
        ii += 1
      i += 1
    
    for item_idx, node_idx of item_node     
      @syncObject parent_node.children[node_idx], match[item_idx], false

    # Clean up nodes that no longer correspond to data.
    i = num_children - 1
    while i
      i -= 1
      if node_item[i] is undefined
        parent_node.removeChild parent_node.children[i]

    # Insert new nodes
    item_idx = 0
    while item_idx < match.length
      if item_node[item_idx] is undefined
        item = match[item_idx]
        # Create the new node cloned from the collection template.
        node = tpl_node.cloneNode true
        node.style.display = ''
        tpl_node.parentNode.insertBefore node, parent_node.children[item_idx]
        # Bind the dom to the data.
        $(node).data 'item', item
        # Sync the new element to the data.
        @syncObject node, item, false

      item_idx += 1


  depth: 0

  sync: -> # This is almost definitely bad. meh.
    unless timeout
      timeout = setTimeout =>
          console.log 'syncing...'
          timeout = null
          @redraw()
        , 25
  
  redraw: ->
    if @onredraw
      @onredraw()
    else # does this work at all? (defautl redraw behaviour)
      @syncRoot @$.data 'item'
    
    # execute queued functions pending redraw
    while review.deferred.length
      review.deferred.pop()()

  syncRoot: (data) ->
    @_cache = {} # Clear synced cache of calculated values.
    @$.data 'item', data
    @syncObject @$.get(0), data, true
    @afterSync? data
  
  scope: (marker) ->
    if @[marker]
      @_cache[marker] ?= @[marker]()
    else
      null

  syncObject: (node, data, skip=false) ->

    #@print node, data

    # Keep track of recursion depth.
    @depth += 1

    if data is undefined
      @depth -= 1
      return

    unless skip
      classes = get_classes node
      for c in classes
        # Transition to a new view class if one is appropriate.
        if view_registry['.'+c]
          child_view = get_closest_view node, '.'+c
          child_view.syncRoot data
          @depth -= 1
          return # Switched to child view, so stop traversing with this one.

        if data[c] isnt undefined
          match = data[c]
          break

        if @[c]
          #console.log c
          match = @scope c
          #console.log match

    #if data._id
    #  node.setAttribute? 'data-item-id', data._id
    match_type = typeof match
    if match_type isnt 'undefined'
      
      # Strings should be rendered to the node, and exit recursion.
      if match_type is 'string' or match_type is 'boolean' or match_type is 'number'

        @syncTerminal node, match
        @depth -= 1
        return # Strings are "leaves"

      else if match instanceof Array
        @syncArray node, match
        @depth -= 1
        return # Arrays rendering is handled, return.
      
      else if match_type is 'object'
        data = match # Walk into the object
        $(node).data 'item', match

      else if match_type is 'function'
        data = match node # Evaluate the function
    
    # Traverse the node's children with the same data (skip nodes, or use new data)
    node = node.firstElementChild
    while node
      @syncObject node, data
      node = node.nextElementSibling
    @depth -= 1

namespace.init = (node, data)->
  (get_closest_view node).syncRoot data