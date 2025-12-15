import matplotlib as mpl
import matplotlib.pyplot as plt
import pandas as pd

CYAN = "#26a5b8"
MAGENTA = "#dd0075"
YELLOW = "#ffcc00"
GREEN = "#61B776"
PURPLE = "#612aa1"
ORANGE = "#ff9900"


class CF:
    """Color class."""

    cyan = CYAN
    magenta = MAGENTA
    yellow = YELLOW
    green = GREEN
    purple = PURPLE
    orange = ORANGE
    colours = [CYAN, MAGENTA, YELLOW, GREEN, PURPLE, ORANGE]

    @staticmethod
    def set_colours():
        """Set colours"""
        mpl.rcParams["axes.prop_cycle"] = mpl.cycler(color=CF.colours)


def show_trivial_demo():
    """Trivial color demo"""

    _df = pd.DataFrame()
    _df.index = list(range(10))
    _df["y1"] = _df.index**2
    _df["y2"] = _df.index**3

    msg1 = "Before setting CF colours (please quit this popup window now)"
    print(msg1)
    _df.plot(lw=5, title=msg1)
    plt.show()

    msg2 = "After setting CF colours:"
    print(msg2)
    CF.set_colours()
    _df.plot(lw=5, title=msg2)
    plt.show()


if __name__ == "__main__":
    show_trivial_demo()
