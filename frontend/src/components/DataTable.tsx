import type { ReactNode } from "react";

export interface Column<T> {
  header: string;
  render: (row: T) => ReactNode;
}

interface Selection {
  selected: ReadonlySet<number>;
  onToggle: (index: number) => void;
  onToggleAll: () => void;
}

// `selection` is optional: pass it to show a checkbox column for mass actions.
export function DataTable<T>({ columns, rows, selection }: { columns: Column<T>[]; rows: T[]; selection?: Selection }) {
  const allSelected = selection !== undefined && rows.length > 0 && selection.selected.size === rows.length;
  return (
    <div className="table-wrap">
      <table className="table">
        <thead>
          <tr>
            {selection && (
              <th className="check">
                <input type="checkbox" aria-label="Select all" checked={allSelected} onChange={selection.onToggleAll} />
              </th>
            )}
            {columns.map((c) => (
              <th key={c.header}>{c.header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 && (
            <tr>
              <td colSpan={columns.length + (selection ? 1 : 0)} className="muted">
                No data
              </td>
            </tr>
          )}
          {rows.map((row, i) => (
            <tr key={i} className={selection?.selected.has(i) ? "selected" : undefined}>
              {selection && (
                <td className="check">
                  <input
                    type="checkbox"
                    aria-label={`Select row ${i + 1}`}
                    checked={selection.selected.has(i)}
                    onChange={() => selection.onToggle(i)}
                  />
                </td>
              )}
              {columns.map((c) => (
                <td key={c.header}>{c.render(row)}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
