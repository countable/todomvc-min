
data =
  todos: [
      title: 'first title'
      completed: false
    ,
      title: 'second title'
      completed: true
  ]


filters = 
  'filter-all': (todo)-> true
  'filter-active': (todo)-> not todo.completed
  'filter-completed': (todo)-> todo.completed


$ ->

  review.view '.todoapp',
    
    active_filter: 'filter-all'

    events:
      'keydown #new-todo': (e)->
        if e.which is 13
          data.todos.unshift
            title: e.target.value
            completed: false
          e.target.value = ''
 
      'click #filters': (e)-> @active_filter = e.target.className

      'change #toggle-all': ->
        all_checked = @scope 'n-completed'
        for todo in data.todos
          todo.completed = not all_checked

      'click #clear-completed': -> data.todos = data.todos.filter (item)-> not item.completed

    'n-completed': -> data.todos.filter( (item)-> item.completed ).length

    'n-left': -> data.todos.length - @scope('n-completed')
    
    afterSync: (data)->
      @$.find('#filters *').removeClass 'selected' # crap, prefer to use a matched attribute as above (n-left etc.)
      @$.find('.'+@active_filter).addClass 'selected' # crap, same as above.

    onredraw: ->
      @syncRoot data # crap, should be automatic, right? shouldn't root.item be data?


  review.view '.todo',
    
    events:
      'change .toggle[type="checkbox"]': (e)->
        @item.completed = e.target.checked
        true # cause a redraw

      'dblclick .view label': ->
        @parent().editing_todo = @item
        # focus the input once it appears. (after redraw)
        @defer => $('[type="text"]:visible').focus()
        

      'blur [type="text"]': (e)->
        @item.title = e.target.value
        @stopEditing()
      
      'keydown [type="text"]': (e)->
        if e.which is 13
          @stopEditing()
        if e.which is 27
          @stopEditing()
        else
          false # prevent redraw

      'click .destroy': (e)->
        data.todos = data.todos.filter (item)=>
          item isnt @item
    
    
    stopEditing: ->
      @parent().editing_todo = null # No race condition because dblclick happens later than focusout.
      @$.removeClass 'editing'
        
    afterSync: (todo)-> # crap, but necessary for jQuery plugins anyway.
      @$.toggleClass 'editing', @parent().editing_todo is todo
      @$.toggleClass 'completed', todo.completed
      @$.toggleClass 'hidden', not filters[@parent().active_filter] todo

    onredraw: ->
      # always trigger parent to repaint. perhaps this should be discoverable by the fact we touch the parent in event handlers.
      # or the fact the parent renders some items based on the child's data.
      @parent().redraw()



  review.init $(".todoapp").get(0), data  # crap - this should be discovered.

