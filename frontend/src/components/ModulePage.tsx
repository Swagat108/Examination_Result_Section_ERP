import { useEffect, useMemo, useState } from "react";
import { api } from "../lib/api";
import { ControlPanel } from "./ControlPanel";
import { DataTable, type Column } from "./DataTable";

interface ModuleResponse<T> {
  group: string;
  title: string;
  items: T[];
}

// Shared list-screen scaffold: control panel (search + mass-action area) and a selectable table.
// Add your module's bulk actions next to the "Clear selection" button; the selected rows are `rows` filtered by `selected`.
export function ModulePage<T>({ module, columns }: { module: string; columns: Column<T>[] }) {
  const [data, setData] = useState<ModuleResponse<T> | null>(null);
  const [error, setError] = useState("");
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<Set<number>>(new Set());

  useEffect(() => {
    api<ModuleResponse<T>>(`/${module}`)
      .then(setData)
      .catch((e: Error) => setError(e.message));
  }, [module]);

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!data) return [];
    return q ? data.items.filter((r) => JSON.stringify(r).toLowerCase().includes(q)) : data.items;
  }, [data, query]);

  if (error) return <ControlPanel title="Something went wrong" subtitle={error} />;
  if (!data) return <ControlPanel title="Loading" />;

  const toggle = (i: number) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (!next.delete(i)) next.add(i);
      return next;
    });
  const toggleAll = () => setSelected(selected.size === rows.length ? new Set() : new Set(rows.map((_, i) => i)));
  const updateQuery = (value: string) => {
    setQuery(value);
    setSelected(new Set());
  };

  return (
    <>
      <ControlPanel title={data.title} subtitle={`Owned by ${data.group}. Sample data until the SQL layer is wired.`}>
        {selected.size > 0 && (
          <>
            <span className="tag">{selected.size} selected</span>
            <button className="secondary" onClick={() => setSelected(new Set())}>
              Clear selection
            </button>
          </>
        )}
        <input type="search" placeholder="Search..." value={query} onChange={(e) => updateQuery(e.target.value)} />
      </ControlPanel>
      <div className="content">
        <DataTable columns={columns} rows={rows} selection={{ selected, onToggle: toggle, onToggleAll: toggleAll }} />
      </div>
    </>
  );
}
