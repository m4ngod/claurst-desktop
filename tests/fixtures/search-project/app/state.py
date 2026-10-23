from dataclasses import dataclass, replace


@dataclass(frozen=True)
class SearchState:
    query: str = ""
    status: str = "all"
    sort_order: str = "newest"

    def set_query(self, query):
        return replace(self, query=query)

    def set_status(self, status):
        return SearchState(status=status, sort_order=self.sort_order)


def visible_records(records, state):
    return [record for record in records
            if (state.status == "all" or record["status"] == state.status)
            and state.query.casefold() in record["title"].casefold()]
