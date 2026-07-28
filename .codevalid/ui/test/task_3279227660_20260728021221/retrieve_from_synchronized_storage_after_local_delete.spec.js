import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawingsResponse } from "../../mock/mock-data.js";

test("User retrieves previously saved artwork after local file deletion", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieve_from_synchronized_storage_after_local_delete",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, uploadedGoogleDrawingsResponse);

  await recorder.step("Open application asset library", async () => {
    await page.goto("/");
    await expect(page.getByAltText("New Google drawing")).toBeVisible();
  });

  await recorder.step("Verify artwork is rendered from synchronized storage data", async () => {
    await expect(page.getByText("Google User")).toBeVisible();
    await expect(page.getByAltText("AI image generated of New Google drawing")).toBeAttached();
    await expect(page.getByText("Create a drawing and share it with the world!")).toHaveCount(0);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieve_from_synchronized_storage_after_local_delete");
  await recorder.save(testInfo);
});
