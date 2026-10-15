#include <cassert>
#include <iostream>
#include <set>
#include "mem/ruby/network/garnet/flexible-pipeline/HetSubPolicy.hh"

int main()
{
    HetSub::Geometry g;
    std::set<int> tiles;
    for (int h = 0; h < 64; ++h) {
        assert(g.hilbert(g.tile(h)) == h);
        tiles.insert(g.tile(h));
        if (h) {
            int a = g.tile(h - 1), b = g.tile(h);
            assert(std::abs(a / 8 - b / 8) +
                   std::abs(a % 8 - b % 8) == 1);
        }
    }
    assert(tiles.size() == 64);
    for (int a = 0; a < 64; ++a) {
        for (int b = 0; b < 64; ++b) {
            int current = a, hops = 0;
            while (current != b) {
                int next = g.next(current, b);
                assert(g.distance(next, b) + 1 == g.distance(current, b));
                current = next;
                assert(++hops <= 63);
            }
            assert(hops == g.distance(a, b));
            for (int end = 0; end < 64; ++end) {
                bool allowed = end != a &&
                    g.distance(a, end) + g.distance(end, b) ==
                    g.distance(a, b);
                assert(g.shortcutAllowed(a, end, b) == allowed);
            }
        }
    }
    for (int width : {7, 8, 16}) {
        for (int bytes = 1; bytes <= 256; ++bytes) {
            int sum = 0, n = HetSub::flitCount(bytes, width);
            for (int i = 0; i < n; ++i)
                sum += HetSub::validBytes(i, bytes, width);
            assert(sum == bytes);
            assert(n * width >= bytes && (n - 1) * width < bytes);
        }
    }
    HetSub::Selection s;
    assert(s.preview(false, false) == 0);
    assert(s.preview(false, true) == 1);
    s.sample(12, 16, 0, 16);
    int mesh = 0;
    for (int i = 0; i < 8; ++i) {
        // Failed attempts can preview repeatedly without changing the choice.
        int chosen = s.preview(false, false);
        assert(s.preview(false, false) == chosen);
        mesh += chosen;
        s.commit(false, false);
    }
    assert(mesh == 2 && s.quarters() == 1);
    s.sample(10, 16, 0, 16); // L stays congested inside hysteresis band.
    assert(s.quarters() == 2 && s.preview(true, false) == 0);
    s.sample(12, 16, 12, 16);
    assert(s.quarters() == 1);
    s.sample(8, 16, 0, 16);
    assert(s.quarters() == 0 && s.preview(false, false) == 0);
    std::cout << "PASS: 4096 L routes, 262144 shortcut predicates, "
                 "width conservation, selection hysteresis and retry\n";
}
