import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAnonymousOnlySession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import {
  anonymousPersistedDrawingsResponse,
} from "../../mock/mock-data.js";

test("Anonymous session preserves drawings across browser refreshes", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "anonymous_session_persists_between_refreshes",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock anonymous persisted drawings session");
  await mockAnonymousOnlySession(page);
  await mockDrawingsList(page, anonymousPersistedDrawingsResponse);

  await recorder.step("Open drawings list as anonymous user");
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();
  await expect(page.getByText("Anonymous User")).toBeVisible();

  await recorder.step("Refresh browser and verify anonymous drawings remain visible");
  await page.reload();
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();
  await expect(page.getByText("Anonymous User")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:anonymous_session_persists_between_refreshes");
  await recorder.save(testInfo);
});
