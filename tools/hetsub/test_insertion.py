#!/usr/bin/env python3
"""Independent invariants for the production offline insertion algorithm."""
import unittest
from collections import Counter
from insert_shortcuts import candidates, hilbert_order, insert, resources


class InsertionTests(unittest.TestCase):
    def test_paper_center_ranks(self):
        order = hilbert_order()
        top = list(c for c in candidates({}) if c['level'] == 1)
        endpoints = {c['src'] for c in top} | {c['dst'] for c in top}
        self.assertEqual({order.index(t) + 1 for t in endpoints}, {11, 32, 33, 54})
        self.assertTrue(all(c['level'] in (1, 2) for c in candidates({})))

    def test_conflicts_and_budget(self):
        profile = {(s, d): 1 for s in range(64) for d in range(64)}
        links, audit = insert(profile, 0, 20)
        self.assertGreater(len(links), 0)
        self.assertTrue(any(r['reason'] == 'conflict' for r in audit))
        self.assertEqual([c['level'] for c in links],
                         sorted(c['level'] for c in links))
        incoming, outgoing, edges = set(), set(), set()
        for link in links:
            i, o, e = resources(link['path'])
            self.assertFalse(incoming & i)
            self.assertFalse(outgoing & o)
            self.assertFalse(edges & e)
            incoming |= i
            outgoing |= o
            edges |= e
        self.assertTrue(all(n <= 1 for n in Counter(c['src'] for c in links).values()))
        self.assertTrue(all(n <= 1 for n in Counter(c['dst'] for c in links).values()))
        small, _ = insert(profile, 0, 2)
        self.assertEqual(small, links[:2])

    def test_threshold_and_subregion_flow(self):
        self.assertEqual(insert({}, 0, 4)[0], [])
        profile = {(s, d): 1 for s in range(64) for d in range(64)}
        # Top-level child pairs aggregate 16x16 bytes. Smaller levels have 4x4.
        links, _ = insert(profile, 255, 4)
        self.assertTrue(links)
        self.assertTrue(all(c['level'] == 1 and c['flow_bytes'] == 256 for c in links))
        self.assertEqual(insert(profile, 256, 4)[0], [])

    def test_level2_only_selection(self):
        # All level-1 inter-child flows are zero; one level-2 flow exceeds the
        # threshold, so the only selected shortcut is a level-2 pair.
        profile = {(10, 17): 1152}
        links, audit = insert(profile, 128, 4)
        self.assertEqual(links, [dict(level=2, src=10, dst=17,
                                      flow_bytes=1152, path=[10, 9, 17])])
        self.assertTrue(all(r['level'] == 1 and r['flow_bytes'] == 0 and
                            r['reason'] == 'below_threshold' for r in audit if r['level'] == 1))
        self.assertEqual([r for r in audit if r['level'] == 2 and r['reason'] == 'selected'],
                         [dict(level=2, src=10, dst=17, flow_bytes=1152, reason='selected')])

    def test_invalid_path(self):
        for path in ([0, 9], [0, 1, 2, 3], [7, 8], [0, 1, 0]):
            with self.assertRaises(ValueError): resources(path)


if __name__ == '__main__':
    unittest.main()
