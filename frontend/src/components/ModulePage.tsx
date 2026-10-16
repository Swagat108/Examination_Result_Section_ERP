import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { DataTable, type Column } from "./DataTable";

interface ModuleResponse<T> {
  group: string;
  title: string;
  items: T[];
}

// Shared list-screen scaffold: fetches GET /api/<module> and renders a table.
// Extend or replace it for forms, detail views and reports in your module.
export function ModulePage<T>({ module, columns }: { module: string; columns: Column<T>[] }) {
  const [data, setData] = useState<ModuleResponse<T> | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api<ModuleResponse<T>>(`/${module}`)
      .then(setData)
      .catch((e: Error) => setError(e.message));
  }, [module]);

  if (error) return <p className="error">{error}</p>;
  if (!data) return <p className="muted">Loading...</p>;
  return (
    <>
      <h1>{data.title}</h1>
      <p className="muted">Owned by {data.group}. Sample data until the SQL layer is wired.</p>
      <DataTable columns={columns} rows={data.items} />
    </>
  );
}
