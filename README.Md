# TODOMVC.min

This is my attempt to write a _generic_ library to implement the TodoMvc app as simply as possible.

Of course, I didn't "cheat" by making the library too specific to the problem of writing a TODO list. At least not much. We also do include jQuery for basic DOM manipulation - not sure how I feel about this but not hard to remove it either...

I feel the resulting code is nearly as terse as a definition in any language could reasonably be, under 100 lines. See todo.coffee


# Contributing

I welcome any help making this even smaller and simpler. There are comments like this where I've noted deficiencies:

```
    afterSync: (data)->
      @$.find('#filters *').removeClass 'selected' # crap, prefer to use a matched attribute as above (n-left etc.)

```


# Testing

Go to http://countable.github.io/todomvc-min/

OR

```
git clone <this repo>
open index.html
```
