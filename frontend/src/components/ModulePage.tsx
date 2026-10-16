import { useEffect, useState } from "react";
import { api } from "../lib/api";
import { DataTable, type Column } from "./DataTable";
import { PageHero } from "./PageHero";

interface ModuleResponse<T> {
  group: string;
  title: string;
  items: T[];
}

// Shared list-screen scaffold: fetches GET /api/<module> and renders a hero band plus a table band.
// Extend or replace it for forms, detail views and reports in your module.
export function ModulePage<T>({ module, columns }: { module: string; columns: Column<T>[] }) {
  const [data, setData] = useState<ModuleResponse<T> | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api<ModuleResponse<T>>(`/${module}`)
      .then(setData)
      .catch((e: Error) => setError(e.message));
  }, [module]);

  if (error) return <PageHero title="Something went wrong" lead={error} />;
  if (!data) return <PageHero title="Loading" />;
  return (
    <>
      <PageHero title={data.title} lead={`Owned by ${data.group}. Sample data until the SQL layer is wired.`} />
      <section className="band band-soft">
        <div className="container">
          <DataTable columns={columns} rows={data.items} />
        </div>
      </section>
    </>
  );
}
