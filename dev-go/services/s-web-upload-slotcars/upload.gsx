package module

component Catalog() {
	<Page title="Slotcars">
		<DropZone action="/upload" accept=".xlsx" label="Drag or upload spreadsheet"/>
	</Page>
}

component Images(id string, kinds []string) {
	<Page title={ "Uploading images for " + id }>
		{ for _, kind := range kinds {
			<DropZone action={ "/image/" + id + "/" + kind } accept={imageAccept} label={ "Drag or upload " + kind + " image" }/>
		} }
	</Page>
}
