#!/usr/bin/python26

from varnishstats import VarnishStats
from collections import deque
import subprocess
import tornado.ioloop
import tornado.web

class StatsWrapper(object):
    depth = 15
    d = None
    def __init__(self):
        self.d = deque(maxlen = self.depth)
        for i in range(self.depth):
            si = VarnishStats()
            for k,v in vars(si).items():
                si.__dict__["%s_delta" % k] = 0
                si.__dict__["%s_delta_1min" % k] = 0
                si.__dict__["%s_delta_5min" % k] = 0
                si.__dict__["%s_delta_15min" % k] = 0
                si.__dict__["%s_1min" % k] = 0
                si.__dict__["%s_5min" % k] = 0
                si.__dict__["%s_15min" % k] = 0
                self.d.append(si)

    def update(self):
        si = VarnishStats()
        p = subprocess.Popen(["/usr/bin/varnishstat", "-1", "-n", "couponcabin"], bufsize=4096, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, close_fds=True)
        p.stdin.close()
        out = p.stdout.readlines()
        pairs = [ i.rstrip('\n').split(None,3) for i in out ]
        for (k,v,r,f) in pairs:
            if v <= 0: continue
            if hasattr(VarnishStats,k) : si.__dict__[k] = float(v)

        for k,v in vars(si).items():
            c = 0
            for i in self.d:

                if c < 1:
                    si.__dict__["%s_delta" % k] = int(round(si.__dict__["%s" % k ] - i.__dict__["%s" % k] ))

                if c < 2:
                    si.__dict__["%s_1min" % k] = int(round((i.__dict__["%s_1min" % k] + si.__dict__["%s" % k]) / 2 ))
                    si.__dict__["%s_delta_1min" % k] = int(round( (i.__dict__["%s_delta_1min" % k] + si.__dict__["%s_delta" % k]) / 2 ))
                
                if c <= 5:
                    si.__dict__["%s_5min" % k] = int(round( (i.__dict__["%s_5min" % k] + si.__dict__["%s" % k]) / 2 ))
                    si.__dict__["%s_delta_5min" % k] = int(round( (i.__dict__["%s_delta_5min" % k] + si.__dict__["%s_delta" % k]) / 2 ))

                si.__dict__["%s_15min" % k] = int(round( (i.__dict__["%s_15min" % k] + si.__dict__["%s" % k]) /2 ))
                si.__dict__["%s_delta_15min" % k] = int(round( (i.__dict__["%s_delta_15min" % k] + si.__dict__["%s_delta" % k]) /2 ))
                si.__dict__[k] = int(si.__dict__[k])

                c += 1
        self.d.appendleft(si)

    def dump(self,key=None):
        vs = self.d[0]
        ret = " ".join(["%s=%s" % (k,v) for k,v in vs.__dict__.iteritems() if key is None or k.startswith(key)])

        return ret

    def get(self):
        return self.write(self.dump())

class MainHandler(tornado.web.RequestHandler):
    def get(self, key):
        sw = self.application.sw
        self.write(sw.dump(key))

class Application(tornado.web.Application):
    def __init__(self):
        self.sw = StatsWrapper()
        handlers = [
            (r"/(.*)", MainHandler)
        ]

        settings = dict()

        tornado.web.Application.__init__(self, handlers, **settings)

    def update(self):
        self.sw.update()



def main(options):
    app = Application()
    app.listen(options.port)
    ioloop = tornado.ioloop.IOLoop.instance()
    scheduler = tornado.ioloop.PeriodicCallback(app.update,60000, io_loop = ioloop)
    scheduler.start()
    ioloop.start() 
