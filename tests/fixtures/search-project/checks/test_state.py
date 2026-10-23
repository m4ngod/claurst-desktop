import unittest
from app.state import SearchState, visible_records


class SearchChecks(unittest.TestCase):
    def test_status_change_keeps_search(self):
        state = SearchState(query="银杏", sort_order="oldest").set_status("done")
        self.assertEqual(state.query, "银杏", "search query lost after status change")
        self.assertEqual(state.status, "done")
        self.assertEqual(state.sort_order, "oldest")

    def test_status_and_query_both_filter(self):
        records = [{"title": "银杏报告", "status": "done"},
                   {"title": "松树报告", "status": "done"},
                   {"title": "银杏草稿", "status": "open"}]
        state = SearchState(query="银杏").set_status("done")
        self.assertEqual(visible_records(records, state), [records[0]])

    def test_search_change_preserves_other_state(self):
        state = SearchState(status="open", sort_order="oldest").set_query("report")
        self.assertEqual(state.status, "open")
        self.assertEqual(state.sort_order, "oldest")


if __name__ == "__main__":
    unittest.main()
