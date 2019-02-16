#
# Copyright (c) 2018 T2T Inc. All rights reserved
# https://www.t2t.io
# https://tic-tac-toe.io
# Taipei, Taiwan
#

class Dictionary
  (@opts) ->
    @keyword-map = {}
    @keyword-list = []
    return

  find-index: (k) ->
    {keyword-map, keyword-list} = self = @
    index = keyword-map[k]
    return index if index?
    keyword-map[k] = index = keyword-list.length
    keyword-list.push k
    return index

  load: (keywords) ->
    self = @
    self.keyword-map = {}
    self.keyword-list = []
    [ self.find-index k for k in keywords ]

  get-strings: -> return @keyword-list

  get-keyword: (index) ->
    return null unless index >= 0 and index < @keyword-list.length
    return @keyword-list[index]



class TagSet
  (@dict, @p_type=null, @p_id=null, @s_type=null, @s_id=null) ->
    @id = -1
    return unless p_type?
    return unless p_id?
    return unless s_type?
    return unless s_id?
    @name = "#{p_type}/#{p_id}/#{s_type}/#{s_id}"
    @tokens = tokens = [p_type, p_id, s_type, s_id]
    @indexes = [ dict.find-index t for t in tokens ]
    return

  get-name: -> return @name
  get-strings: -> return @tokens
  get-indexes: -> return @indexes

  load: (p_type_idx, p_id_idx, s_type_idx, s_id_idx) ->
    {dict} = self = @
    xs = <[p_type p_id s_type s_id]>
    self.indexes = indexes = [p_type_idx, p_id_idx, s_type_idx, s_id_idx]
    self.tokens = tokens = [ dict.get-keyword idx for idx in indexes ]
    for let x, i in xs
      keyword = tokens[i]
      if keyword?
        self[x] = keyword
        # console.log "self[#{x}] = #{keyword}"
      else
        console.error "TagSet: failed to find index #{indexes[i]} for tag name #{x}"
    {p_type, p_id, s_type, s_id} = self
    self.name = "#{p_type}/#{p_id}/#{s_type}/#{s_id}"
    # console.log "TagSet: successfully load #{self.name}"



class FieldSet
  (@dict, @fields=[]) ->
    self = @
    @id = -1
    @name = ""
    @indexes = []
    @fields = [] unless @fields?
    return if @fields.length is 0
    @name = @fields.join ","
    @indexes = [ dict.find-index f for f in self.fields ]

  get-name: -> return @name
  get-strings: -> return @fields
  get-indexes: -> return @indexes

  load: (@indexes) ->
    {dict} = self = @
    self.fields = [ dict.get-keyword idx for idx in indexes ]
    self.name = self.fields.join ","

  get: (index) ->
    return @fields[index]



class Measurement
  (@timestamp, @tag-set, @field-set, @value-set) ->
    return

  to-json-object: ->
    {timestamp, tag-set, field-set, value-set} = self = @
    measurement = tag-set.id
    field_set = field-set.id
    values = value-set
    return {timestamp, measurement, field_set, values}

  to-json-array: ->
    {timestamp, tag-set, field-set, value-set} = self = @
    measurement = tag-set.id
    field_set = field-set.id
    values = value-set
    return [timestamp, measurement, field_set, values]

  to-line: ->
    {timestamp, tag-set, field-set, value-set} = self = @
    measurement = tag-set.id
    field_set = field-set.id
    vs = value-set.join ","
    xs = [timestamp, measurement, field_set, vs]
    return xs.join " "

  to-sensor-event-object: (array=no) ->
    {timestamp, tag-set, field-set, value-set} = self = @
    {p_type, p_id, s_type, s_id} = tag-set
    xs = [ {data_type: (field-set.get i), value: v} for let v, i in value-set ]
    return {timestamp, p_type, p_id, s_type, s_id, xs} unless array
    xs = { [(field-set.get i), v] for let v, i in value-set }
    {epoch} = timestamp
    return [epoch, p_type, p_id, s_type, s_id, xs]



class IndexingList
  (@opts) ->
    @object-map = {}
    @object-list = []
    return

  reset: ->
    @object-map = {}
    @object-list = []

  add: (obj) ->
    {object-list, object-map} = self = @
    {name} = obj
    o = object-map[name]
    return o if o?
    id = object-list.length
    obj.id = id
    object-list.push obj
    object-map[name] = obj
    return obj

  get: (index) ->
    return @object-list[index]

  get-strings: ->
    {object-list} = self = @
    return [ (o.get-strings!) for o in object-list ]

  get-indexes: ->
    {object-list} = self = @
    return [ (o.get-indexes!) for o in object-list ]


module.exports = exports = {Dictionary, TagSet, FieldSet, Measurement, IndexingList}