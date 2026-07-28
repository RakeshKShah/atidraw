import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockDrawingsList } from "../../helpers/mock-api.js";
import { syncedStorageSourceOfTruthResponse } from "../../mock/mock-data.js";

test("System retrieves artwork using synchronized blob storage as source of truth", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieves_from_synced_storage_as_source_of_truth",
    testTitle: "System retrieves artwork using synchronized blob storage as source of truth",
  });

  await recorder.step("Mock GET /api/drawings using synchronized storage metadata payload", async () => {
    await mockDrawingsList(page, syncedStorageSourceOfTruthResponse);
  });

  await recorder.step("Navigate to homepage", async () => {
    await page.goto("/");
  });

  await recorder.step("Verify local drawing renders without an AI overlay", async () => {
    await expect(page.getByText("Local Artist")).toBeVisible();
    await expect(page.getByAltText("Synced local drawing")).toBeVisible();
    await expect(page.getByAltText("AI image generated of Synced local drawing")).toHaveCount(0);
  });

  await recorder.step("Verify remote AI image renders with AI overlay based on blob metadata", async () => {
    await expect(page.getByText("Remote Artist")).toBeVisible();
    await expect(page.getByAltText("Synced remote AI artwork")).toBeVisible();
    await expect(page.getByAltText("AI image generated of Synced remote AI artwork")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieves_from_synced_storage_as_source_of_truth");
  await recorder.save(testInfo);
});
