class WidgetCache:
    def __init__(self):
        self._cache = {}

    def get(self, widget_id):
        return self._cache.get(widget_id)

    def set(self, widget_id, value):
        self._cache[widget_id] = value
