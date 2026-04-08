export const dynamic = "force-dynamic";

import { ClientListPage, listClientsAction } from "@features/clients";

export default async function Page() {
	const clients = await listClientsAction();
	return <ClientListPage clients={clients} />;
}
