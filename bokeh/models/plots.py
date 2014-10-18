from __future__ import absolute_import

from ..plot_object import PlotObject
from ..properties import Bool, Int, String, Color, Enum, Instance, List, Dict, Include
from ..mixins import LineProps, TextProps
from .. enums import Location

from .. import _glyph_functions
from ..utils import nice_join
from ..query import find

from .widget import Widget
from .sources import DataSource
from .ranges import Range, Range1d
from .renderers import Renderer, GlyphRenderer
from .tools import Tool
from .glyphs import Glyph

# TODO (bev) dupe, move to utils
class _list_attr_splat(list):
    def __setattr__(self, attr, value):
        for x in self:
            setattr(x, attr, value)

class PlotContext(PlotObject):
    """ A container for multiple plot objects. """
    children = List(Instance(PlotObject))

class PlotList(PlotContext):
    # just like plot context, except plot context has special meaning
    # everywhere, so plotlist is the generic one
    pass

class Plot(Widget):
    """ Object representing a plot, containing glyphs, guides, annotations.
    """

    def __init__(self, **kwargs):
        if 'border_symmetry' in kwargs:
            border_symmetry = kwargs.pop('border_symmetry')
            if border_symmetry is None: border_symmetry = ""
            kwargs.setdefault('h_symmetry', 'h' in border_symmetry or 'H' in border_symmetry)
            kwargs.setdefault('v_symmetry', 'v' in border_symmetry or 'V' in border_symmetry)
        super(Plot, self).__init__(**kwargs)

    def select(self, selector):
        ''' Query this object and all of its references for objects that
        match the given selector.

        Args:
            selector (JSON-like) :

        Returns:
            seq[PlotObject]

        '''
        return _list_attr_splat(find(self.references(), selector, {'plot': self}))

    def row(self, row, gridplot):
        ''' Return whether this plot is in a given row of a GridPlot.

        Args:
            row (int) : index of the row to test
            gridplot (GridPlot) : the GridPlot to check

        Returns:
            bool

        '''
        return self in gridplot.row(row)

    def column(self, col, gridplot):
        ''' Return whether this plot is in a given column of a GridPlot.

        Args:
            col (int) : index of the column to test
            gridplot (GridPlot) : the GridPlot to check

        Returns:
            bool

        '''
        return self in gridplot.column(col)

    def add_layout(self, obj, place='center'):
        ''' Adds an object to the plot in a specified place.

        Args:
            obj (PlotObject) : the object to add to the Plot
            place (str, optional) : where to add the object (default: 'center')
                Valid places are: 'left', 'right', 'above', 'below', 'center'.

        Returns:
            None

        '''
        valid_places = ['left', 'right', 'above', 'below', 'center']
        if place not in valid_places:
            raise ValueError(
                "Invalid place '%s' specified. Valid place values are: %s" % (place, nice_join(valid_places))
            )

        if hasattr(obj, 'plot'):
            if obj.plot is not None:
                 raise ValueError("object to be added already has 'plot' attribute set")
            obj.plot = self

        self.renderers.append(obj)

        if place is not 'center':
            getattr(self, place).append(obj)

    def add_tools(self, *tools):
        ''' Adds an tools to the plot.

        Args:
            *tools (Tool) : the tools to add to the Plot

        Returns:
            None

        '''
        if not all(isinstance(tool, Tool) for tool in tools):
            raise ValueError("All arguments to add_tool must be Tool subclasses.")

        for tool in tools:
            if tool.plot is not None:
                 raise ValueError("tool %s to be added already has 'plot' attribute set" % tools)
            tool.plot = self
            self.tools.append(tool)

    def add_glyph(self, source, glyph, **kw):
        ''' Adds a glyph to the plot with associated data sources and ranges.

        This function will take care of creating and configurinf a Glyph object,
        and then add it to the plot's list of renderers.

        Args:
            source: (ColumnDataSource) : a data source for the glyphs to all use
            glyph (Glyph) : the glyph to add to the Plot

        Keyword Arguments:
            Any additional keyword arguments are passed on as-is to the
            Glyph initializer.

        Returns:
            glyph : Glyph

        '''
        if not isinstance(glyph, Glyph):
            raise ValueError("glyph arguments to add_glyph must be Glyph subclass.")

        g = GlyphRenderer(data_source=source, glyph=glyph, **kw)
        self.renderers.append(g)
        return g

    data_sources = List(Instance(DataSource))

    x_range = Instance(Range)
    y_range = Instance(Range)
    x_mapper_type = String('auto')
    y_mapper_type = String('auto')

    extra_x_ranges = Dict(String, Instance(Range1d))
    extra_y_ranges = Dict(String, Instance(Range1d))

    title = String('')
    title_props = Include(TextProps)
    outline_props = Include(LineProps)

    # A list of all renderers on this plot; this includes guides as well
    # as glyph renderers
    renderers = List(Instance(Renderer))
    tools = List(Instance(Tool))

    left = List(Instance(PlotObject))
    right = List(Instance(PlotObject))
    above = List(Instance(PlotObject))
    below = List(Instance(PlotObject))

    toolbar_location = Enum(Location)

    plot_height = Int(600)
    plot_width = Int(600)

    background_fill = Color("white")
    border_fill = Color("white")

    min_border_top = Int(50)
    min_border_bottom = Int(50)
    min_border_left = Int(50)
    min_border_right = Int(50)
    min_border = Int(50)

    h_symmetry = Bool(True)
    v_symmetry = Bool(False)

    annular_wedge     = _glyph_functions.annular_wedge
    annulus           = _glyph_functions.annulus
    arc               = _glyph_functions.arc
    asterisk          = _glyph_functions.asterisk
    bezier            = _glyph_functions.bezier
    circle            = _glyph_functions.circle
    circle_cross      = _glyph_functions.circle_cross
    circle_x          = _glyph_functions.circle_x
    cross             = _glyph_functions.cross
    diamond           = _glyph_functions.diamond
    diamond_cross     = _glyph_functions.diamond_cross
    image             = _glyph_functions.image
    image_rgba        = _glyph_functions.image_rgba
    image_url         = _glyph_functions.image_url
    inverted_triangle = _glyph_functions.inverted_triangle
    line              = _glyph_functions.line
    multi_line        = _glyph_functions.multi_line
    oval              = _glyph_functions.oval
    patch             = _glyph_functions.patch
    patches           = _glyph_functions.patches
    quad              = _glyph_functions.quad
    quadratic         = _glyph_functions.quadratic
    ray               = _glyph_functions.ray
    rect              = _glyph_functions.rect
    segment           = _glyph_functions.segment
    square            = _glyph_functions.square
    square_cross      = _glyph_functions.square_cross
    square_x          = _glyph_functions.square_x
    text              = _glyph_functions.text
    triangle          = _glyph_functions.triangle
    wedge             = _glyph_functions.wedge
    x                 = _glyph_functions.x

class GridPlot(Plot):
    """ A 2D grid of plots """

    children = List(List(Instance(Plot)))
    border_space = Int(0)

    def select(self, selector):
        ''' Query this object and all of its references for objects that
        match the given selector.

        Args:
            selector (JSON-like) :

        Returns:
            seq[PlotObject]

        '''
        return _list_attr_splat(find(self.references(), selector, {'gridplot': self}))

    def column(self, col):
        ''' Return a given column of plots from this GridPlot.

        Args:
            col (int) : index of the column to return

        Returns:
            seq[Plot] : column of plots

        '''
        try:
            return [row[col] for row in self.children]
        except:
            return []

    def row(self, row):
        ''' Return a given row of plots from this GridPlot.

        Args:
            rwo (int) : index of the row to return

        Returns:
            seq[Plot] : rwo of plots

        '''
        try:
            return self.children[row]
        except:
            return []
